/**
 * Shomer login form behaviour.
 *
 * Two pure helpers (formatError, validateCredentials) plus the
 * `setupLoginForm` wiring. The pure helpers are unit-tested under
 * tests/; the wiring is exercised via jsdom in the same test file.
 */

export function formatError(reason: string): string {
  if (!reason) return "";
  return `Sign-in failed: ${reason}`;
}

export interface Credentials {
  username: string;
  password: string;
}

export function validateCredentials(creds: Credentials): string | null {
  if (!creds.username.trim()) return "username required";
  if (!creds.password) return "password required";
  if (creds.password.length < 8) return "password must be at least 8 characters";
  return null;
}

export function setupLoginForm(form: HTMLFormElement): void {
  form.addEventListener("submit", (event) => {
    const data = new FormData(form);
    const creds: Credentials = {
      username: String(data.get("username") ?? ""),
      password: String(data.get("password") ?? ""),
    };
    const error = validateCredentials(creds);
    if (error !== null) {
      event.preventDefault();
      const slot = form.querySelector<HTMLElement>(".error");
      if (slot) {
        slot.textContent = formatError(error);
      }
    }
  });
}

if (typeof document !== "undefined") {
  const form = document.querySelector<HTMLFormElement>("form#login");
  if (form) setupLoginForm(form);
}
