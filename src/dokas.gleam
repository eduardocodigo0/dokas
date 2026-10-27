import dokas/app
import lustre

/// Entry point called by the generated JavaScript bundle. Mounts the Lustre
/// application onto the `<div id="app"></div>` element created by the build.
pub fn main() -> Nil {
  let assert Ok(_) = lustre.start(app.application(), "#app", Nil)
  Nil
}
