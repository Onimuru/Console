; ** Data Type Cpnversion ** ;: http://ahkscript.org/ursrc/Windows_Data_Types.html

Class Structure {
	Static ProcessHeap := DllCall("Kernel32\GetProcessHeap", "Ptr")
		, ThrowException := 1

	;* new Structure(struct*)
	;* new Structure(bytes, (zeroFill))
	__New(params*) {
		if (RegExReplace(params[1].__Class, "S).*?\.(?!.*?\..*?)") == "__Structure") {
			bytes := 0

			for i, struct in params {
				bytes += struct.Size  ;* Calculate the total size for all structures being added.
			}

			pointer := DllCall("Kernel32\HeapAlloc", "Ptr", this.ProcessHeap, "UInt", 0, "Ptr", bytes, "Ptr")  ;* Allocate the memory.
				, offset := 0

			for i, struct in params {
				size := struct.Size

				DllCall("Ntdll\RtlCopyMemory", "Ptr", pointer + offset, "Ptr", struct.Pointer, "Ptr", size), offset += size  ;* Copy the data to the new address and offset the pointer to the next byte in this structure.
			}
		}
		else {
			bytes := params[1]

			if (bytes == Round(bytes) && bytes >= 0) {
				pointer := DllCall("Kernel32\HeapAlloc", "Ptr", this.ProcessHeap, "UInt", (params[2]) ? (0x00000008) : (0), "Ptr", bytes, "Ptr")
			}
			else if (this.ThrowException) {
				throw, (Exception("Invalid Assignment", -1, Format("""{}"" is invalid. This value must be a non negative integer.", bytes)))
			}
		}

		return ({"Pointer": pointer

			, "Base": this.__Structure})
	}

	Class __Structure {

		__Delete() {
			DllCall("Kernel32\HeapFree", "Ptr", Structure.ProcessHeap, "UInt", 0, "Ptr", this.Pointer, "UInt")
		}

		Size[zero := 0] {
			Get {
				return (DllCall("Kernel32\HeapSize", "Ptr", Structure.ProcessHeap, "UInt", 0, "Ptr", this.Pointer, "Ptr"))
			}

			Set {
				if (pointer := DllCall("Kernel32\HeapReAlloc", "Ptr", Structure.ProcessHeap, "UInt", (zero) ? (0x00000008) : (0), "Ptr", this.Pointer, "Ptr", value, "Ptr")) {
					this.Pointer := pointer  ; ** If HeapReAlloc fails, the original memory is not freed, and the original handle and pointer are still valid. **
				}
				else if (Structure.ThrowException) {
					throw, (Exception("Critical Failue", -1, Format("Kernel32\HeapReAlloc failed to allocate memory.")))
				}

				return
			}
		}

		NumGet(offset, type, bytes := 0) {
			if (offset == Round(offset) && offset >= 0) {
				if (type == "Struct" && bytes == Round(bytes) && bytes >= 0) {  ;* Create and return a new struct from a slice of another.
					if (offset + bytes < this.Size) {  ;* Ensure that the memory from `offset` to `offset` + `bytes` is part of this struct.
						struct := new Structure(bytes)
						DllCall("Ntdll\RtlCopyMemory", "Ptr", struct.Pointer, "Ptr", this.Pointer + offset, "Ptr", bytes)

						return (struct)
					}

					return  ;~ No error handling.
				}

				return (NumGet(this.Pointer + offset, type))
			}
			else if (Structure.ThrowException) {
				throw, (Exception("Invalid Assignment", -1, Format("""{}"" is invalid. This value must be a non negative integer.", offset)))
			}
		}

		NumPut(offset, params*) {
			if (offset == Round(offset) && offset >= 0) {
				Static sizeLookup := {"Char": 1, "UChar": 1, "Short": 2, "UShort": 2, "Float": 4, "Int": 4, "UInt": 4, "Int64": 8, "UInt64": 8, "Ptr": A_PtrSize, "UPtr": A_PtrSize}

				pointer := this.Pointer

				loop, % params.Length()//2 {
					index := A_Index*2
						, value := params[index], type := params[index - 1]

					if (type == "Struct") {
						size := value.Size, limit := this.Size - offset
							, bytes := (size > limit) ? (limit) : (size)  ;* Ensure that there is capacity left after accounting for the offset. It is entirely possible to insert a value that exceeds 2 bytes in size into the last 2 bytes of this struct's memory however, thereby corrupting the value.

						if (bytes) {
							DllCall("Ntdll\RtlCopyMemory", "Ptr", pointer + offset, "Ptr", value.Pointer, "Ptr", bytes), offset += bytes
						}
					}
					else {
						size := sizeLookup[type], limit := this.Size - offset
							, bytes := (size > limit) ? (limit) : (size)

						if (bytes - size == 0) {
							NumPut(value, pointer + offset, type), offset += bytes
						}
					}
				}
			}
			else if (Structure.ThrowException) {
				throw, (Exception("Invalid Assignment", -1, Format("""{}"" is invalid. This value must be a non negative integer.", offset)))
			}

			return (offset)  ;* Similar to `Push()` returning position of the last inserted value.
		}

		StrGet(offset, length, encoding := "None") {
			return (StrGet(this.Pointer, length, encoding))  ;? "UTF-8", "UTF-16", "CP936", "CP0"
		}

		ZeroMemory(bytes := 0) {
			size := this.Size
				, bytes := (bytes) ? ((bytes > size) ? (size) : (bytes)) : (this.Size)

			DllCall("Ntdll\RtlZeroMemory", "Ptr", this.Pointer, "Ptr", bytes)
		}
	}
}