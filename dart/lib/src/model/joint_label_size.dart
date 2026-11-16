/// Size of every joint label in a document (spec 04, JS-1).
///
/// The font size of each value comes from `JointStyle.labelFontSize`.
enum JointLabelSize {
  /// The base size, `JointStyle.labelBaseFontSize` (default 30).
  small,

  /// The base size plus one step (default 34).
  medium,

  /// The base size plus two steps (default 38).
  large,
}
