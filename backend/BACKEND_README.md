# Planova Backend - Development Guide

## Overview
The Planova backend is a Node.js/Express API that:
1. Handles floorplan image uploads and registration
2. Triggers image processing via Python service
3. Manages graph data (nodes/edges) in Firestore
4. Provides REST API endpoints for the mobile app

---

## Project Structure

```
backend/
├── server.js                 # Main Express server
├── fake-python.js           # Mock Python service for testing
├── package.json             # Backend dependencies
├── .env                     # Environment variables (Firebase config)
├── firebase.json            # Firebase configuration
├── .firebaserc              # Firebase project ID
│
├── config/
│   └── firebase.js          # Firebase Admin initialization
│
├── middleware/
│   └── auth.middleware.js   # Firebase token verification
│
├── routes/
│   ├── image.routes.js      # Image upload endpoints
│   └── graph.routes.js      # Graph retrieval endpoints
│
├── controllers/
│   ├── image.controller.js  # Upload & status logic
│   └── graph.controller.js  # Graph retrieval logic
│
├── services/
│   └── python.service.js    # Python service integration
│
└── functions/               # Firebase Cloud Functions
    ├── index.js            # Firestore trigger: onFloorplanCreated
    ├── package.json
    └── .firebaserc
```

---

## Setup

### Prerequisites
- Node.js 24+
- npm or yarn
- Firebase CLI (`npm install -g firebase-tools`)

### Installation

```bash
# 1. Install main backend dependencies
npm install

# 2. Install Firebase Functions dependencies
cd functions
npm install
cd ..

# 3. Verify .env file has Firebase credentials
cat .env
```

---

## Running the Backend

### Option 1: Manual Start (3 Terminals)

**Terminal 1: Fake Python Service**
```bash
node fake-python.js
```
✅ Runs on `http://localhost:7000`

**Terminal 2: Express Server**
```bash
node server.js
```
✅ Runs on `http://localhost:5000`

**Terminal 3: Firebase Functions (Windows)**
```bash
cd functions
npm run serve
```
✅ Runs on `http://localhost:5001`

### Option 2: Single Command (Bash/Linux/Mac)
```bash
./dev-start.sh
```

---

## API Endpoints

### 1. **Upload Floorplan Image**
```
POST /api/image/upload
Content-Type: application/json

{
  "imageUrl": "https://example.com/floorplan.jpg"
}
```

**Response:**
```json
{
  "message": "Floorplan registered",
  "id": "floorplan_doc_id"
}
```

**What happens:**
- Saves floorplan to Firestore with `processed: false`
- Calls Python service to process image
- Saves resulting graph (nodes/edges) to Firestore
- Marks floorplan as `processed: true`

---

### 2. **Check Processing Status**
```
GET /api/image/:id/status
```

**Response:**
```json
{
  "processed": true  // or false if still processing
}
```

---

### 3. **Retrieve Graph by Floorplan**
```
GET /api/graph/:floorplanId
```

**Response:**
```json
{
  "id": "graph_doc_id",
  "floorplanId": "floorplan_id",
  "nodes": [
    { "id": "Entrance" },
    { "id": "Hallway" },
    { "id": "Room1" }
  ],
  "edges": [
    { "from": "Entrance", "to": "Hallway" },
    { "from": "Hallway", "to": "Room1" }
  ],
  "createdAt": "2026-02-03T10:30:00Z"
}
```

---

### 4. **Protected Route (Test Auth)**
```
GET /protected
Authorization: Bearer YOUR_FIREBASE_ID_TOKEN
```

**Response:**
```json
{
  "message": "You are authenticated",
  "user": "firebase_uid"
}
```

---

## Database Schema (Firestore)

### Collection: `floorplans`
```
{
  imageUrl: string,           // URL to uploaded image
  processed: boolean,         // True when graph is ready
  createdAt: timestamp,       // Upload time
}
```

### Collection: `graphs`
```
{
  floorplanId: string,        // Reference to floorplan doc
  nodes: Array<{              // Building layout nodes
    id: string
  }>,
  edges: Array<{              // Connections between nodes
    from: string,
    to: string
  }>,
  createdAt: timestamp
}
```

---

## Firebase Cloud Functions

### Trigger: `onFloorplanCreated`
- **Event:** New document created in `floorplans` collection
- **Action:** Automatically processes the floorplan image
- **Process:**
  1. Reads imageUrl from floorplan document
  2. Calls Python service: `POST http://localhost:7000/process`
  3. Saves response (nodes/edges) to `graphs` collection
  4. Updates floorplan document with `processed: true`

---

## Integration with Kenneth (Image Processing)

**Current:** Using `fake-python.js` to test

**When Kenneth's service is ready:**
1. Replace `http://localhost:7000/process` with Kenneth's API endpoint
2. Update `functions/index.js` line 18 with actual service URL
3. Update `services/python.service.js` with production URL
4. No other code changes needed!

**Expected Input from Kenneth:**
```json
{
  "floorplanId": "string",
  "imageUrl": "string"
}
```

**Expected Output from Kenneth:**
```json
{
  "nodes": [
    { "id": "string" }
  ],
  "edges": [
    { "from": "string", "to": "string" }
  ]
}
```

---

## Integration with Jhay Elle (A* Pathfinding)

The `nodes` and `edges` from the graph are ready for pathfinding:
- Create an endpoint: `POST /api/route/:floorplanId`
- Accept: `{ startNode: string, endNode: string }`
- Call Jhay Elle's A* service with the graph
- Return: `{ path: [node_ids], directions: [...] }`

---

## Integration with JP (Flutter App)

The app will:
1. Upload image → `POST /api/image/upload`
2. Poll for status → `GET /api/image/:id/status`
3. Once ready → `GET /api/graph/:floorplanId`
4. Display graph nodes on map
5. Request routes → `POST /api/route/:floorplanId` (future)

---

## Testing the API

### Using cURL

**1. Upload a floorplan:**
```bash
curl -X POST http://localhost:5000/api/image/upload \
  -H "Content-Type: application/json" \
  -d '{"imageUrl":"https://example.com/floorplan.jpg"}'
```

**2. Check status:**
```bash
curl http://localhost:5000/api/image/{id}/status
```

**3. Get graph:**
```bash
curl http://localhost:5000/api/graph/{floorplanId}
```

---

## Environment Variables (.env)

```env
PORT=5000
FIREBASE_PROJECT_ID="planova-6d4b9"
FIREBASE_CLIENT_EMAIL="firebase-adminsdk-fbsvc@planova-6d4b9.iam.gserviceaccount.com"
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
```

---

## Troubleshooting

### Server won't start
```bash
# Check if port 5000 is in use
lsof -i :5000  # Mac/Linux
netstat -ano | findstr :5000  # Windows
```

### Functions emulator issues
```bash
# Clear emulator data
firebase emulators:start --only functions --clear
```

### Firebase authentication errors
- Verify `.env` has correct credentials
- Check Firebase project ID matches `.firebaserc`

---

## Next Steps (Priority Order)

1. ✅ **Current:** Backend API working with fake Python
2. ⏳ **Next:** Integrate Kenneth's image processor
3. ⏳ **Then:** Add Jhay Elle's pathfinding service
4. ⏳ **Finally:** Connect with JP's Flutter app

---

## Git Workflow

```bash
# Pull latest
git pull origin backend-dev

# Make changes
git add .
git commit -m "Description of changes"

# Push to backend-dev branch
git push origin backend-dev
```

---

## Contact / Questions

- **Prince** (Backend): Lead backend development
- **Kenneth** (Image Processing): Integration point for image processor
- **Jhay Elle** (Pathfinding): Integration point for routing algorithm
- **JP** (Frontend): API consumer

---

**Last Updated:** February 3, 2026
