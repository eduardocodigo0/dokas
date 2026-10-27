// Thin wrapper around the browser APIs used by the application.
//
// Every function has two implementations: a real one for the JavaScript target
// (in `ffi_ffi.mjs`) and a harmless stub for the Erlang target so that the
// project can still be compiled and tested there (e.g. `gleam test`).

/// Reads a value from the browser's localStorage. Returns an empty string when
/// the key is missing or storage is unavailable.
@external(erlang, "dokas_ffi", "local_storage_get")
@external(javascript, "./ffi_ffi.mjs", "localStorageGet")
pub fn local_storage_get(key: String) -> String

/// Persists a value in the browser's localStorage. Failures are ignored (for
/// example in private browsing mode with storage disabled).
@external(erlang, "dokas_ffi", "local_storage_set")
@external(javascript, "./ffi_ffi.mjs", "localStorageSet")
pub fn local_storage_set(key: String, value: String) -> Nil
