const request = require('supertest');

// Create a fresh app instance for each test
let app;

beforeEach(() => {
  // Clear the require cache to get a fresh app
  delete require.cache[require.resolve('../index')];
  // Reset NODE_ENV to test for clean state
  process.env.NODE_ENV = 'test';
  app = require('../index');
});

describe('API Integration Tests', () => {
  describe('POST /votes', () => {
    test('creates a new vote with valid data', async () => {
      const res = await request(app)
        .post('/votes')
        .send({ title: 'Test Vote', content: 'Test Content' })
        .expect(201);
      expect(res.body).toHaveProperty('id');
      expect(res.body.title).toBe('Test Vote');
    });

    test('returns 400 when title is missing', async () => {
      const res = await request(app)
        .post('/votes')
        .send({ content: 'No title' })
        .expect(400);
      expect(res.body.error).toBe('title is required');
    });
  });

  describe('GET /votes', () => {
    test('retrieves all votes', async () => {
      const res = await request(app)
        .get('/votes')
        .expect(200);
      expect(Array.isArray(res.body)).toBe(true);
    });
  });

  describe('GET /health', () => {
    test('returns UP status', async () => {
      const res = await request(app)
        .get('/health')
        .expect(200);
      expect(res.body.status).toBe('UP');
    });
  });

  describe('GET /metrics', () => {
    test('returns Prometheus metrics', async () => {
      const res = await request(app)
        .get('/metrics')
        .expect(200);
      expect(res.text).toContain('http_request_duration_seconds');
    });
  });
});
