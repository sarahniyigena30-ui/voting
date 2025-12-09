import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [options, setOptions] = useState([]);
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [voted, setVoted] = useState(false);

  useEffect(() => {
    fetchOptions();
    fetchResults();
  }, []);

  const fetchOptions = async () => {
    try {
      const response = await axios.get('/api/options');
      setOptions(response.data);
      setLoading(false);
    } catch (err) {
      setError('Failed to load options');
      setLoading(false);
    }
  };

  const fetchResults = async () => {
    try {
      const response = await axios.get('/api/results');
      setResults(response.data);
    } catch (err) {
      console.error('Failed to load results', err);
    }
  };

  const handleVote = async (optionId) => {
    try {
      await axios.post('/api/vote', { option_id: optionId });
      setVoted(true);
      fetchResults();
    } catch (err) {
      setError('Failed to submit vote');
    }
  };

  if (loading) {
    return <div className="loading">Loading...</div>;
  }

  if (error) {
    return <div className="error">{error}</div>;
  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>🗳️ Voting System</h1>
        <p>Cast your vote below</p>
      </header>

      <main className="App-main">
        {!voted ? (
          <div className="voting-section">
            <h2>Vote for your favorite option:</h2>
            <div className="options-grid">
              {options.map((option) => (
                <button
                  key={option.id}
                  className="option-button"
                  onClick={() => handleVote(option.id)}
                >
                  {option.name}
                </button>
              ))}
            </div>
          </div>
        ) : (
          <div className="thank-you">
            <h2>✅ Thank you for voting!</h2>
            <button onClick={() => setVoted(false)} className="vote-again">
              View Options Again
            </button>
          </div>
        )}

        <div className="results-section">
          <h2>Current Results:</h2>
          <div className="results-list">
            {results.map((result) => (
              <div key={result.id} className="result-item">
                <div className="result-header">
                  <span className="result-name">{result.name}</span>
                  <span className="result-votes">{result.votes} votes</span>
                </div>
                <div className="result-bar">
                  <div
                    className="result-fill"
                    style={{
                      width: `${
                        (result.votes /
                          Math.max(...results.map((r) => r.votes), 1)) *
                        100
                      }%`,
                    }}
                  ></div>
                </div>
              </div>
            ))}
          </div>
          <button onClick={fetchResults} className="refresh-button">
            🔄 Refresh Results
          </button>
        </div>
      </main>

      <footer className="App-footer">
        <p>DevOps Voting System - CI/CD Pipeline Demo</p>
      </footer>
    </div>
  );
}

export default App;
