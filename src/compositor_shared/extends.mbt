///|
/// Explicit method promotion.
///
/// Derived trait implementations are no longer implicitly promoted to regular
/// methods. This file makes the promotions we actually want explicit, which
/// keeps `x.equal(y)`, `x.not_equal(y)`, and `x.to_repr()` available without
/// the `implicit_impl_as_method` deprecation warning.

// BlendMode
pub extend BlendMode with Eq::{equal, not_equal}

///|
pub extend BlendMode with @debug.Debug::{to_repr}

// Mask

///|
pub extend Mask with Eq::{equal, not_equal}

///|
pub extend Mask with @debug.Debug::{to_repr}

// Layer

///|
pub extend Layer with Eq::{equal, not_equal}

///|
pub extend Layer with @debug.Debug::{to_repr}

// Color

///|
pub extend Color with Eq::{equal, not_equal}

///|
pub extend Color with @debug.Debug::{to_repr}

// Brush

///|
pub extend Brush with Eq::{equal, not_equal}

///|
pub extend Brush with @debug.Debug::{to_repr}

// Tool

///|
pub extend Tool with Eq::{equal, not_equal}

///|
pub extend Tool with @debug.Debug::{to_repr}

// Snapshot (document content only, no debug needed)

///|
pub extend Snapshot with Eq::{equal, not_equal}

// Model (editor state, no debug needed)

///|
pub extend Model with Eq::{equal, not_equal}
