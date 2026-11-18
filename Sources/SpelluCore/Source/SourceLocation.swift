import struct Basis.FilePath


public enum SourceLocation : Equatable, Sendable {
	
	case temporary
	case memory(_ name: String?)
	case file(_ path: FilePath)
	
}



