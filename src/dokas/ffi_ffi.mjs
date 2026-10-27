// JavaScript implementation of the browser bindings declared in ffi.gleam.

function storage() {
  try {
    return typeof window !== "undefined" ? window.localStorage : null;
  } catch {
    return null;
  }
}

export function localStorageGet(key) {
  const local = storage();
  if (local === null) {
    return "";
  }
  try {
    const value = local.getItem(key);
    return value === null ? "" : value;
  } catch {
    return "";
  }
}

export function localStorageSet(key, value) {
  const local = storage();
  if (local === null) {
    return;
  }
  try {
    local.setItem(key, value);
  } catch {
    // Ignore quota errors and disabled storage: the app keeps working in memory.
  }
}
