import codecs
import re
import os
from icecream import ic

DIR = "."
HTML = "html/"
GABC = "gabc/"
TEX = "tex/"
TEX_NG = "tex_no_gloria/"


def latexify(data:str, name:str) -> str:
	new_string = ""
	patterns = {
		#r"(<span style='float:left;width:25pt;text-align:right;'>)[0-9]+(\.&nbsp;<\/span>)": "",
		r"(<span style='float:left;width:25pt;text-align:right;'>)": "",
		r"(&nbsp;<\/span>)": " ",
		r"(<i>)": r'\\textit{',
		r"(<\/i>)": r'}',
		r"(<b>)": r'\\textbf{',
		r"(<\/b>)": r'}',
		r"(<br\/>)": '\\\\\n',
		r"&nbsp;\*": r' \\ast\\ ',
		r"&nbsp;†": r" \\dag\\ ",
	}
	for line in data:
		for pattern, replacement in patterns.items():
			line = re.sub(pattern, replacement, line)
		new_string += line
	newname = name.split("/")[1].split(".")[0] + ".tex"
	with open(os.path.join(TEX, newname), "w") as f:
		#for line in new_string:
		f.write(new_string)
	with open(os.path.join(TEX, newname), "r") as f:
		text = f.readlines()
		size = len(text)
		ic(size)
		with open(os.path.join(TEX_NG,newname), "w") as o:
			i = 1
			for line in text:
				if i == size-3:
					break
				else:
					o.write(line)
					i +=1
	return 0

for i, filename in enumerate(os.listdir(HTML)):
	filename = HTML + filename
	if not filename.endswith(".html"):
		pass
	else:
		with open(filename, "r") as f:
			try:
				data = f.readlines()
			except UnicodeDecodeError:
				sourceFileName = filename
				targetFileName = filename.split(".")[0] + "fixed.html"
				BLOCKSIZE = 1048576
				with codecs.open(sourceFileName, "r", "your-source-encoding") as sourceFile:
					with codecs.open(targetFileName, "w", "utf-8") as targetFile:
						while True:
							contents = sourceFile.read(BLOCKSIZE)
							if not contents:
								break
							targetFile.write(contents)
			ic(i, filename)
			latexify(data, filename)
