package m28.keyvalue;

/**
 * ...
 * @author Matheus28
 */

class KeyValue {
	static public function stringify(obj:Dynamic):String {
		return encode(obj, true);
	}
	static private function encode(obj:Dynamic, root:Bool):String {
		#if js
			if (obj == null) {
				return 'null';
			}else if (untyped __js__('typeof obj == "number"')) {
				return untyped obj.toString();
			}else if (untyped __js__('typeof obj == "boolean"')) {
				return obj.toString();
			}else if (untyped __js__('typeof obj == "string"')) {
				if (isKeyword(obj) || !isIdentifier(obj)) {
					return '"' + escapeString(obj) + '"';
				}else {
					return obj;
				}
				
			}else if (untyped __js__('obj instanceof Array')) {
				return '[' + map(obj, function(elem) { return encode(elem, false); }).join(' ') + ']';
			}else {
				var str = '';
				if (!root) str += '{';
				untyped __js__("var first=true;for(var i in obj){if(!first) str += ' ';first = false;str += this.encode(i, false)+' '+this.encode(obj[i], false);};");
				if (!root) str += '}';
				
				return str;
			}
		#else
			if (obj == null) {
				return 'null';
			}else if (Std.is(obj, Float)) {
				return untyped obj.toString();
			}else if (Std.is(obj, Bool)) {
				return obj.toString();
			}else if (Std.is(obj, String)) {
				if (isKeyword(obj) || !isIdentifier(obj)) {
					return '"' + escapeString(obj) + '"';
				}else {
					return obj;
				}
				
			}else if (Std.is(obj, Array)) {
				return '[' + map(obj, function(elem) { return encode(elem, false); }).join(' ') + ']';
			}else {
				var str = '';
				if (!root) str += '{';
				str += return map(Reflect.fields(obj), function(i) { return encode(i, false) + ' ' + encode(Reflect.field(obj, i), false); } ).join(' ');
				
				if (!root) str += '}';
				
				return str;
			}
		#end
		
	}
	
	static public function parse(str:String):Dynamic {
		var TYPE_BLOCK = 0;
		var TYPE_ARRAY = 1;
		var i = 0;
		var line = 1;
		var depth = 0;
		var tree:Array<Dynamic> = [{}];
		var treeType:Array<Int> = [TYPE_BLOCK];
		var keys:Array<String> = [null];
		while(i < str.length){
			var chr = str.charAt(i);
			if (chr == ' ' || chr == '\t') {
				
			}else if(chr == '\n'){
				++line;
				if (str.charAt(i + 1) == '\r') ++i;
			}else if(chr == '\r'){
				++line;
				if (str.charAt(i + 1) == '\n') ++i;
			}else if(chr == '"'){
				var startIndex = i++;
				var resultString:String = '';
				while (i < str.length) {
					chr = str.charAt(i);
					if (chr == '"' || chr == '\n' || chr == '\r') break;
					
					if (chr == '\\') {
						++i;
						chr = str.charAt(i);
						switch(chr) {
							case '\\': chr = '\\';
							case '"': chr = '"';
							case '\'': chr = '\'';
							case 'n': chr = '\n';
							case 'r': chr = '\r';
							default: throw "Invalid escape character \""+chr+"\" at line " + line;
						}
					}
					
					resultString += chr;
					
					++i;
				}
				
				if (i == str.length || chr == '\n' || chr == '\r') throw "Unterminated string at line " + line;
				
				if(treeType[treeType.length - 1] == TYPE_BLOCK){
					if (keys[keys.length - 1] == null) {
						keys[keys.length - 1] = resultString;
					}else {
						Reflect.setField(tree[tree.length - 1], keys[keys.length - 1], resultString);
						keys[keys.length - 1] = null;
					}
				}else if (treeType[treeType.length - 1] == TYPE_ARRAY) {
					tree[tree.length - 1].push(resultString);
				}
				
				if(chr != '"') --i; // Reparse the character that ended this string
			}else if (chr >= '0' && chr <= '9') {
				var startIndex = i++;
				while (i < str.length) {
					chr = str.charAt(i);
					if ((chr < '0' || chr > '9') && chr != '.' && chr != 'x') break;
					++i;
				}
				
				var resultNumber = Std.parseInt(str.substr(startIndex, i - startIndex));
				if (resultNumber == null) throw "Invalid number at line " + line + " (offset " + i + ")";
				
				if(treeType[treeType.length - 1] == TYPE_BLOCK){
					if (keys[keys.length - 1] == null) {
						throw "A number can't be the key of a value at line " + line + " (offset " + i + ")";
					}else {
						Reflect.setField(tree[tree.length - 1], keys[keys.length - 1], resultNumber);
						keys[keys.length - 1] = null;
					}
				}else if (treeType[treeType.length - 1] == TYPE_ARRAY) {
					tree[tree.length - 1].push(resultNumber);
				}
				
				--i; // Reparse the character that ended this number
			}else if (chr == '{') {
				if(treeType[treeType.length - 1] == TYPE_BLOCK){
					if (keys[keys.length - 1] == null) {
						throw "A block needs a key at line " + line + " (offset " + i + ")";
					}
				}
				
				tree.push({});
				treeType.push(TYPE_BLOCK);
				keys.push(null);
			}else if (chr == '}') {
				if (tree.length == 1) {
					throw "Mismatching bracket at line " + line + " (offset " + i + ")";
				}
				if (treeType.pop() != TYPE_BLOCK) {
					throw "Mismatching brackets at line " + line + " (offset " + i + ")";
				}
				keys.pop();
				var obj = tree.pop();
				
				if(treeType[treeType.length - 1] == TYPE_BLOCK){
					Reflect.setField(tree[tree.length - 1], keys[keys.length - 1], obj);
					keys[keys.length - 1] = null;
				}else {
					tree[tree.length - 1].push(obj);
				}
			}else if (chr == '[') {
				if(treeType[treeType.length - 1] == TYPE_BLOCK){
					if (keys[keys.length - 1] == null) {
						throw "An array needs a key at line " + line + " (offset " + i + ")";
					}
				}
				
				tree.push([]);
				treeType.push(TYPE_ARRAY);
				keys.push(null);
				
			}else if (chr == ']') {
				if (tree.length == 1) {
					throw "Mismatching bracket at line " + line + " (offset " + i + ")";
				}
				if (treeType.pop() != TYPE_ARRAY) {
					throw "Mismatching brackets at line " + line + " (offset " + i + ")";
				}
				keys.pop();
				var obj = tree.pop();
				
				if(treeType[treeType.length - 1] == TYPE_BLOCK){
					Reflect.setField(tree[tree.length - 1], keys[keys.length - 1], obj);
					keys[keys.length - 1] = null;
				}else {
					tree[tree.length - 1].push(obj);
				}
			}else if ((chr >= 'a' && chr <= 'z') || (chr >= 'A' && chr <= 'Z') || chr == '_' || chr == '$' || chr == '-') {
				var startIndex = i;
				var resultString:String = '';
				
				while (i < str.length) {
					chr = str.charAt(i);
					if ((chr >= 'a' && chr <= 'z') || (chr >= 'A' && chr <= 'Z') || (chr >= '0' && chr <= '9') || chr == '_' || chr == '$' || chr == '-'){
						resultString += chr;
						++i;
					}else {
						break;
					}
				}
				
				var result:Dynamic = resultString;
				switch(resultString) {
					case 'true': result = true;
					case 'false': result = false;
					case 'null': result = null;
					case 'undefined': result = untyped __js__('(void 0)');
				}
				
				if(treeType[treeType.length - 1] == TYPE_BLOCK){
					if (keys[keys.length - 1] == null) {
						keys[keys.length - 1] = result;
					}else {
						Reflect.setField(tree[tree.length - 1], keys[keys.length - 1], result);
						keys[keys.length - 1] = null;
					}
				}else if (treeType[treeType.length - 1] == TYPE_ARRAY) {
					tree[tree.length - 1].push(result);
				}
				
				--i; // Reparse the character that ended this identifier
			}else if (chr == '\') {
				++i;
				while (i < str.length) {
					chr = str.charAt(i);
					++i;
					if(chr == "\n" || chr == "\r"){
						++line;
						break
					}
				}
			}else{
				throw "Unexpected character \"" + chr + "\" at line " + line + " (offset " + i + ")";
			}
			
			++i;
		}
		
		if (tree.length != 1) {
			throw "Missing brackets";
		}
		
		return tree[0];
	}
	
	static inline private function isIdentifier(str:String):Bool {
		return (~/^[a-zA-Z$_-][a-zA-Z0-9$_-]*$/).match(str);
	}
	
	static inline private function escapeString(str:String):String {
		return StringTools.replace(StringTools.replace(StringTools.replace(StringTools.replace(str, '\\', '\\\\'), '"', '\\"'), '\r', '\\r'), '\n', '\\n');
	}
	
	static private function isKeyword(str:String):Bool {
		switch(str) {
			case 'true': return true;
			case 'false': return true;
			case 'null': return true;
			case 'undefined': return true;
			default: return false;
		}
	}
	
	static private inline function isAlphaChar(chr:String):Bool {
		return (chr >= 'a' && chr <= 'z') || (chr >= 'A' && chr <= 'Z');
	}
	
	static private function map<A,B>(it:Iterable<A>, f:A->B):Array<B> {
		var l = [];
		for(x in it)
			l.push(f(x));
		return l;
	}
}