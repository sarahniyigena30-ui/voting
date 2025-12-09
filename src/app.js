// API Base URL
const API_URL = '';

// DOM Elements
const createForm = document.getElementById('createForm');
const voteTitle = document.getElementById('voteTitle');
const voteContent = document.getElementById('voteContent');
const votesList = document.getElementById('votesList');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    loadVotes();
    setupEventListeners();
});

// Setup Event Listeners
function setupEventListeners() {
    createForm.addEventListener('submit', handleCreateVote);
}

// Load all votes
async function loadVotes() {
    try {
        votesList.innerHTML = '<p class="loading">Loading votes...</p>';
        const response = await fetch(`${API_URL}/votes`);
        
        if (!response.ok) throw new Error('Failed to load votes');
        
        const votes = await response.json();
        displayVotes(votes);
    } catch (error) {
        console.error('Error loading votes:', error);
        votesList.innerHTML = '<p class="error">Failed to load votes. Please try again.</p>';
    }
}

// Display votes
function displayVotes(votes) {
    if (votes.length === 0) {
        votesList.innerHTML = '<p class="empty">No votes yet. Create your first vote!</p>';
        return;
    }

    votesList.innerHTML = votes.map(vote => `
        <div class="vote-item" data-id="${vote.id}">
            <div class="vote-header">
                <h3 class="vote-title">${escapeHtml(vote.title)}</h3>
                <span class="vote-id">#${vote.id}</span>
            </div>
            ${vote.content ? `<p class="vote-content">${escapeHtml(vote.content)}</p>` : ''}
            <div class="vote-meta">
                <span class="vote-date">${formatDate(vote.created_at)}</span>
                <div class="vote-actions">
                    <button class="btn-edit" onclick="editVote(${vote.id})">Edit</button>
                    <button class="btn-delete" onclick="deleteVote(${vote.id})">Delete</button>
                </div>
            </div>
        </div>
    `).join('');
}

// Handle create vote
async function handleCreateVote(e) {
    e.preventDefault();
    
    const title = voteTitle.value.trim();
    const content = voteContent.value.trim();
    
    if (!title) {
        alert('Please enter a title');
        return;
    }
    
    try {
        const response = await fetch(`${API_URL}/votes`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ title, content })
        });
        
        if (!response.ok) throw new Error('Failed to create vote');
        
        // Reset form
        createForm.reset();
        
        // Show success message
        showSuccessMessage('Vote created successfully!');
        
        // Reload votes
        await loadVotes();
    } catch (error) {
        console.error('Error creating vote:', error);
        alert('Failed to create vote. Please try again.');
    }
}

// Edit vote
async function editVote(id) {
    const newTitle = prompt('Enter new title:');
    if (!newTitle) return;
    
    const newContent = prompt('Enter new content (optional):');
    
    try {
        const response = await fetch(`${API_URL}/votes/${id}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ 
                title: newTitle, 
                content: newContent || '' 
            })
        });
        
        if (!response.ok) throw new Error('Failed to update vote');
        
        showSuccessMessage('Vote updated successfully!');
        await loadVotes();
    } catch (error) {
        console.error('Error updating vote:', error);
        alert('Failed to update vote. Please try again.');
    }
}

// Delete vote
async function deleteVote(id) {
    if (!confirm('Are you sure you want to delete this vote?')) return;
    
    try {
        const response = await fetch(`${API_URL}/votes/${id}`, {
            method: 'DELETE'
        });
        
        if (!response.ok) throw new Error('Failed to delete vote');
        
        showSuccessMessage('Vote deleted successfully!');
        await loadVotes();
    } catch (error) {
        console.error('Error deleting vote:', error);
        alert('Failed to delete vote. Please try again.');
    }
}

// Utility Functions
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function showSuccessMessage(message) {
    const successDiv = document.createElement('div');
    successDiv.className = 'success-message';
    successDiv.textContent = message;
    
    const main = document.querySelector('main');
    main.insertBefore(successDiv, main.firstChild);
    
    setTimeout(() => {
        successDiv.remove();
    }, 3000);
}
