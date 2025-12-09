const express = require("express");
const fs = require("fs").promises;
const path = require("path");
const morgan = require("morgan"); // For request logging
const client = require("prom-client");
const app = express();

// Serve static files from src directory
app.use(express.static(path.join(__dirname, 'src')));

app.use(express.json());
app.use(morgan("combined")); // Log API requests

// Prometheus metrics setup
const register = new client.Registry();
client.collectDefaultMetrics({ register });
const httpDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.005, 0.01, 0.05, 0.1, 0.5, 1, 2, 5],
});
register.registerMetric(httpDuration);

// ---------------------
// LOCAL STORAGE SETUP
// ---------------------
const DATA_FILE = path.join(__dirname, "votes.json");
let votesData = { votes: [], nextId: 1 };

// Load data from file
async function loadData() {
  try {
    const data = await fs.readFile(DATA_FILE, "utf8");
    votesData = JSON.parse(data);
  } catch (err) {
    if (err.code === "ENOENT") {
      // File doesn't exist, create it
      await saveData();
    } else {
      console.error("Error loading data:", err);
    }
  }
}

// Save data to file
async function saveData() {
  try {
    await fs.writeFile(DATA_FILE, JSON.stringify(votesData, null, 2));
  } catch (err) {
    console.error("Error saving data:", err);
    throw err;
  }
}

// Middleware to observe request durations
app.use((req, res, next) => {
  const start = process.hrtime();
  res.on("finish", () => {
    const diff = process.hrtime(start);
    const durationSeconds = diff[0] + diff[1] / 1e9;
    // Use the defined route if available (for templated routes like /votes/:id)
    const route = req.route && req.route.path ? req.route.path : req.path;
    httpDuration.labels(req.method, route, String(res.statusCode)).observe(durationSeconds);
  });
  next();
});

// ---------------------
// ROUTES
// ---------------------

// Root endpoint
app.get("/", (req, res) => {
  res.json({ 
    message: "Voting System API",
    endpoints: {
      "GET /": "API information",
      "GET /votes": "Get all votes",
      "GET /votes/:id": "Get vote by ID",
      "POST /votes": "Create a new vote (requires: title, content)",
      "PUT /votes/:id": "Update a vote",
      "DELETE /votes/:id": "Delete a vote",
      "GET /health": "Health check",
      "GET /metrics": "Prometheus metrics"
    }
  });
});

// Create a new vote
app.post("/votes", async (req, res) => {
  try {
    const { title, content } = req.body;
    if (!title) return res.status(400).json({ error: "title is required" });
    
    const newVote = {
      id: votesData.nextId++,
      title,
      content: content || null,
      created_at: new Date().toISOString()
    };
    
    votesData.votes.push(newVote);
    await saveData();
    res.status(201).json(newVote);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Storage error" });
  }
});

// Get all votes
app.get("/votes", async (req, res) => {
  try {
    const sortedVotes = [...votesData.votes].sort((a, b) => 
      new Date(b.created_at) - new Date(a.created_at)
    );
    res.json(sortedVotes);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Storage error" });
  }
});

// Get one vote by ID
app.get("/votes/:id", async (req, res) => {
  try {
    const vote = votesData.votes.find(v => v.id === parseInt(req.params.id));
    res.json(vote || {});
  } catch (err) {
    res.status(500).json({ error: "Storage error" });
  }
});

// Update a vote
app.put("/votes/:id", async (req, res) => {
  try {
    const { title, content } = req.body;
    const vote = votesData.votes.find(v => v.id === parseInt(req.params.id));
    
    if (vote) {
      vote.title = title;
      vote.content = content;
      await saveData();
      res.json({ message: "Vote updated" });
    } else {
      res.status(404).json({ error: "Vote not found" });
    }
  } catch (err) {
    res.status(500).json({ error: "Storage error" });
  }
});

// Delete a vote
app.delete("/votes/:id", async (req, res) => {
  try {
    const index = votesData.votes.findIndex(v => v.id === parseInt(req.params.id));
    
    if (index !== -1) {
      votesData.votes.splice(index, 1);
      await saveData();
      res.json({ message: "Vote deleted" });
    } else {
      res.status(404).json({ error: "Vote not found" });
    }
  } catch (err) {
    res.status(500).json({ error: "Storage error" });
  }
});

// Prometheus metrics endpoint
app.get("/metrics", async (req, res) => {
  try {
    res.setHeader("Content-Type", register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err);
  }
});

// ---------------------
// HEALTHCHECK ENDPOINT
// For DevOps monitoring
// ---------------------
app.get("/health", (req, res) => {
  res.json({ status: "UP", timestamp: Date.now() });
});

// Export app for testing
module.exports = app;

// Start server after loading data (only when run directly)
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  let server;
  (async () => {
    try {
      await loadData();
      server = app.listen(PORT, () => {
        console.log(`Voting API running on port ${PORT}`);
        console.log(`Using local storage at: ${DATA_FILE}`);
      });
    } catch (err) {
      console.error("Failed to start server:", err);
      process.exit(1);
    }
  })();

  // Graceful shutdown
  async function shutdown() {
    console.log("Shutting down...");
    try {
      if (server) await new Promise((resolve) => server.close(resolve));
      await saveData(); // Save data before exit
      console.log("Shutdown complete");
      process.exit(0);
    } catch (err) {
      console.error("Error during shutdown", err);
      process.exit(1);
    }
  }

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}
