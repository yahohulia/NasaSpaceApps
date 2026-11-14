import {
  isRouteErrorResponse,
  Link,
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
} from "react-router";

import type { Route } from "./+types/root";
import "./app.css";

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="uk">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <Meta />
        <Links />
      </head>
      <body>
        {children}
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

export function HydrateFallback() {
  return (
    <main>
      <p role="status">
        Завантаження… / <span lang="en">Loading…</span>
      </p>
    </main>
  );
}

export default function App() {
  return <Outlet />;
}

export function ErrorBoundary({ error }: Route.ErrorBoundaryProps) {
  const notFound = isRouteErrorResponse(error) && error.status === 404;

  return (
    <main>
      <h1>{notFound ? "Сторінку не знайдено" : "Щось пішло не так"}</h1>
      <p lang="en">{notFound ? "Page not found." : "Something went wrong."}</p>
      <Link to="/">
        На головну / <span lang="en">Back home</span>
      </Link>
      {import.meta.env.DEV && error instanceof Error && (
        <pre>
          <code>{error.stack ?? error.message}</code>
        </pre>
      )}
    </main>
  );
}
