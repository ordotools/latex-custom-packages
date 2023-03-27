import os
# import regex as re
import re
import shutil


GABC   = './gabc/'
TEX	   = './tex/'
TEX_NG = './text_no_gloria/'
COMP   = './compilations/'

def to_tex(name):
	new_name = name.split('.')[0]+'.tex'
	return new_name

def raw(cooked):
	return r''+cooked

for file in os.listdir(GABC):
	dir_name = file.split('.')[0]
	path = os.path.join(COMP, dir_name.split('-')[0]+'/'+dir_name)
	os.makedirs(path, exist_ok=True)
	shutil.copy(GABC+'/'+file, path+'/'+file)
	with open('main.tex', 'r') as m:
		with open(TEX+'/'+to_tex(file), 'r') as t:
			pass
			# psalms = re.sub('<<psalms>>', t.read(), m.read())
		compiled = re.sub('<<score>>', file, psalms)
	# with open(path+'/main.tex', 'w+') as final:
		# final.write(compiled)
		# shutil.copy(TEX+'/'+to_tex(file), path+'/main.tex')
