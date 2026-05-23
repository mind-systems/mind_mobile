class BciEmotionsDTO {
  final double? attention;
  final double? cognitiveLoad;
  final double? relaxation;
  final double? cognitiveControl;
  final double? selfControl;

  const BciEmotionsDTO({
    this.attention,
    this.cognitiveLoad,
    this.relaxation,
    this.cognitiveControl,
    this.selfControl,
  });
}
