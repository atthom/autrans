# Autrans Frontend

Modern React frontend for the Autrans scheduling application.

## Tech Stack

- **Vite** - Fast build tool and dev server
- **React 18** - UI library
- **TypeScript** - Type safety
- **Tailwind CSS** - Utility-first styling
- **Axios** - HTTP client

## Getting Started

### Development Mode

```bash
# Install dependencies (first time only)
npm install

# Start dev server (with hot reload)
npm run dev
```

The dev server will start at `http://localhost:5173`

**Important:** Make sure the Oxygen backend is running on port 8080:
```bash
# In the project root
julia src/server.jl
```

### Production Build

```bash
# Build for production
npm run build

# Output will be in dist/ directory
```

The Oxygen server will serve these static files in production.

## Project Structure

```
frontend/
├── src/
│   ├── api/           # API client for backend
│   ├── types/         # TypeScript type definitions
│   ├── components/    # React components (to be built)
│   ├── App.tsx        # Main app component
│   ├── main.tsx       # Entry point
│   └── index.css      # Global styles + Tailwind
├── public/            # Static assets
├── dist/              # Build output (generated)
├── vite.config.ts     # Vite configuration
├── tailwind.config.js # Tailwind configuration
└── tsconfig.json      # TypeScript configuration
```

## Development Workflow

1. **Start Oxygen backend** (terminal 1):
   ```bash
   julia src/server.jl
   ```

2. **Start Vite dev server** (terminal 2):
   ```bash
   cd frontend
   npm run dev
   ```

3. **Open browser**:
   - Go to `http://localhost:5173`
   - API calls are proxied to `http://localhost:8080`

4. **Make changes**:
   - Edit React components
   - Browser auto-refreshes instantly!

## API Integration

The frontend communicates with the Oxygen backend via:
- `/schedule` - Generate schedule
- `/export/ics` - Export iCalendar
- `/export/csv` - Export CSV

API client: `src/api/client.ts`
Type definitions: `src/types/index.ts`

## Next Steps

Build out the full UI components:
- Settings panel
- Tasks management
- Workers management
- Constraints configuration
- Schedule display
- Export functionality