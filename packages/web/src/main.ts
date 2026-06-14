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

// Upper bound to keep an honest-but-typo'd password from triggering
// quadratic work on the server-side (bcrypt/argon2 hashing scales
// with input length, and OWASP ASVS 2.1.4 caps the input at 128+);
// 256 leaves headroom for legitimate passphrases while killing
// pathological inputs at the form layer.
const MAX_PASSWORD_LENGTH = 256;

export function validateCredentials(creds: Credentials): string | null {
  if (!creds.username.trim()) return "username required";
  if (!creds.password) return "password required";
  if (creds.password.length < 8) return "password must be at least 8 characters";
  if (creds.password.length > MAX_PASSWORD_LENGTH) {
    return `password must be at most ${MAX_PASSWORD_LENGTH} characters`;
  }
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
      const errorSlot = form.querySelector<HTMLElement>(".error");
      if (errorSlot) {
        errorSlot.textContent = formatError(error);
      }
    }
  });
}

if (typeof document !== "undefined") {
  const form = document.querySelector<HTMLFormElement>("form#login");
  if (form) setupLoginForm(form);
}
