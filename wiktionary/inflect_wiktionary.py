import json
with open('nominal_declensions.json', 'r') as f: nominal_declensions = json.load(f)
with open('verb_conjugations.json', 'r') as f: verb_conjugations = json.load(f)
with open('kotus_types_by_template_name.json', 'r') as f: kotus_types_by_template_name = json.load(f)


def args_to_lua(args):
  output_args = []
  for arg in args:
    if '=' in arg:
      arg = arg.split('=')
      if arg[0].isnumeric():
        arg = '[' + arg[0] + ']="' + arg[1] + '"'
      else:
        arg = '["' + arg[0] + '"]="' + arg[1] + '"'
    else:
      arg = '"' + arg + '"'
    output_args.append(arg)
  return '{' + ', '.join(output_args) + '}'


with open('inflect_wiktionary_generated.lua', 'w', encoding='utf-8') as lua_file:
  lua_file.write('require("inflection")\n')
  for title, template_name, *args in nominal_declensions:
    try:
      kotus_type = kotus_types_by_template_name[template_name]
    except KeyError:
      continue
    lua_file.write('inflect_nominal("' + title + '", "' + kotus_type + '", ' + args_to_lua(args) + ')\n')
  for title, template_name, *args in verb_conjugations:
    try:
      kotus_type = kotus_types_by_template_name[template_name]
    except KeyError:
      continue
    lua_file.write('inflect_verb("' + title + '", "' + kotus_type + '", ' + args_to_lua(args) + ')\n')
