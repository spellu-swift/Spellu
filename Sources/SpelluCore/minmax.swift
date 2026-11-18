

/// value を min と max に収める
public func minmax<T : BinaryInteger>(
	_ value: T,
	min: T,
	max: T,
) -> T {
	Swift.min(Swift.max(min, value), max)
}
