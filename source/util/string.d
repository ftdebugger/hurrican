module hurrican.util.string;

public int indexOf(string haystack, string needle) {
	int index = 0;
	int max = cast(int)(haystack.length - needle.length);

	while(index <= max) {
		if (haystack[index..index+needle.length] == needle) {
			return index;
		}

		index++;
	}

	return -1;
}

unittest {
	import std.stdio;

	assert(indexOf("hello", "el") == 1);
	assert(indexOf("hello", "ab") == -1);
	assert(indexOf("hello\n\n", "\n\n") == 5);
}