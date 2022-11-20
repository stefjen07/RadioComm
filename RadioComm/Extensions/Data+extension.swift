//
//  Data+extension.swift
//  RadioComm
//
//  Created by Евгений on 17.11.22.
//

import Foundation

extension Data {
	mutating func read(stream input: InputStream, size: Int) {
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
		let read = input.read(buffer, maxLength: size)
		self.append(buffer, count: read)
		
		buffer.deallocate()
	}
}
