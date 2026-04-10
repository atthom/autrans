# React Frontend Setup - Complete! ✅

## What We've Built

A modern React frontend foundation for Autrans with:

- ⚡ **Vite** - Lightning-fast dev server with HMR
- ⚛️ **React 18 + TypeScript** - Type-safe component development
- 🎨 **Tailwind CSS** - Utility-first styling
- 🔌 **Axios** - HTTP client for API calls
- 📡 **Proxy Configuration** - Seamless dev/prod API integration

## Project Structure

```
frontend/
├── src/
│   ├── api/
│   │   └── client.ts              # API client with typed methods
│   ├── types/
│   │   └── index.ts               # TypeScript interfaces matching backend
│   ├── components/                # React components (to be built)
│   ├── App.tsx                    # Main app component
│   ├── main.tsx                   # Entry point
│   ├── index.css                  # Global styles + Tailwind
│   └── App.css                    # Component styles
├── public/                        # Static assets
├── dist/                          # Build output (generated)
├── node_modules/                  # Dependencies
├── package.json                   # Dependencies manifest
├── vite.config.ts                 # Vite configuration
├── tailwind.config.js             # Tailwind configuration
├── postcss.config.js              # PostCSS configuration
├── tsconfig.json                  # TypeScript configuration
└── README.md                      # Frontend documentation
```

## Development Workflow

### Start Development

Two options:

**Option 1: All-in-one script**
```bash
# From project root
./start_react_dev.sh
```

**Option 2: Manual (more control)**
```bash
# Terminal 1: Start Oxygen backend
julia scripts/start_server.jl

# Terminal 2: Start Vite dev server
cd frontend
npm run dev
```

Then open `http://localhost:5173` in your browser.

### Key Features

✅ **Hot Module Replacement (HMR)**
- Edit React components → instant browser update
- No manual refresh needed!

✅ **Proxy Configuration**
- `/schedule` → `http://localhost:8080/schedule`
- `/export/*` → `http://localhost:8080/export/*`
- Seamless API calls without CORS issues

✅ **Type Safety**
- All API types defined in `src/types/index.ts`
- Matches Julia backend structures
- Compile-time error checking

✅ **Modern Tooling**
- Fast builds (Vite compiles in ~1s)
- Tree-shaking for optimal bundle size
- Source maps for debugging

## Next Steps

Now that the foundation is ready, we need to build the UI components:

### 1. Settings Panel
- Trip name input
- Start date picker
- Number of days input
- Balance days off toggle

### 2. Tasks Management
- Add/edit/delete tasks
- Task name, workers needed, difficulty
- Day ranges (start/end)
- Color picker

### 3. Workers Management
- Add/edit/delete workers
- Name input
- Days off selector
- Task preferences (with ordering!)
- Workload offset slider

### 4. Constraints Configuration
- List of available constraints
- Enable/disable toggles
- Reorder with drag & drop
- Hard/soft classification
- Descriptions

### 5. Schedule Display
- Table view (workers × days)
- Daily view (grouped by day)
- Audit view (assignment counts)
- Capacity analysis

### 6. Export Functionality
- iCalendar export button
- CSV export button
- Download handling

## Technical Notes

### Tailwind CSS v4
Using the new `@tailwindcss/postcss` plugin (not the legacy `tailwindcss` plugin).

### API Client
The `scheduleApi` in `src/api/client.ts` provides typed methods:
- `generateSchedule(request)` - POST /schedule
- `exportICS(request)` - POST /export/ics
- `exportCSV(request)` - POST /export/csv

### Type Safety
All types in `src/types/index.ts` match the Julia backend:
- `Task`, `Worker`, `Constraint`
- `ScheduleRequest`, `ScheduleResponse`
- `FailureResponse`, `AppState`

## Production Build

When ready for production:

```bash
cd frontend
npm run build
```

Output goes to `frontend/dist/`:
- `index.html` - Entry point
- `assets/index-[hash].js` - Bundled JavaScript
- `assets/index-[hash].css` - Bundled CSS

Then configure Oxygen to serve these static files from `/`.

## Testing the Setup

The current `App.tsx` shows a test page with:
- Tailwind styles working
- React state management working
- Clean, modern UI

Visit `http://localhost:5173` to see it!

---

**Status:** ✅ Foundation complete, ready to build components!