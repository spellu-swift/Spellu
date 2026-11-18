import SpelluCore


/// Sakuya専用の共有導出選択。認識とCommitの境界は変更しない。
final class SharedResolver {

	private let evaluation: Evaluation

	init(evaluation: Evaluation) {
		self.evaluation = evaluation
	}

	func select(_ roots: [Int]) throws -> Session.Match {
		try PackedSelection(evaluation: evaluation, roots: roots).select()
	}

}
