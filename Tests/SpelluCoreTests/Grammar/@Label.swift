import SpelluCore


struct LabelTests {
	
	@Test func equals() {
		#expect(Label("a") == Label("a"))
		#expect(Label("a") != Label.none)
		#expect(Label.none != Label("a"))
		#expect(Label.none == Label.none)
	}

}
