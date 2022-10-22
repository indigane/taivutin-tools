import re
import sys
import xml.etree.ElementTree as ET

try:
  xml_filename = sys.argv[1]
except IndexError:
  print('Usage: python parse_wiktionary.py <path_to_wiktionary_dump.xml>')
  sys.exit()

xml_iter = ET.iterparse(xml_filename, events=('start', 'end'))

template_call_regex = re.compile(r'\{\{(?P<template_call>fi-(?P<inflection_type>conj|decl)-[^}]+)\}\}')
page_data = {}
page_data_attrib = {}
nominal_declensions = []
verb_conjugations = []
kotus_types_by_template_name = {}

NAMESPACE_TERM = "0"
NAMESPACE_TEMPLATE = "10"

for index, (event, elem) in enumerate(xml_iter):
  if index == 0:
    root = elem
    continue
  if event == 'start':
    continue
  if '}' in elem.tag:
    tag_name = elem.tag.split('}', 1).pop()
  else:
    tag_name = elem.tag
  if tag_name == 'page':
    text = page_data.get('text', '') or ''
    title = page_data.get('title', '') or ''
    namespace = page_data.get('ns', '') or ''
    if (
      not title.startswith('-')
      and not title.endswith('-')
      and not title.startswith('.')
      and not ' ' in title
      and not '0' in title
      and not '1' in title
      and not '2' in title
      and not '3' in title
      and not '4' in title
      and not '5' in title
      and not '6' in title
      and not '7' in title
      and not '8' in title
      and not '9' in title
      and '/' not in title
      and len(title) > 1
      and title != 'Template:fi-decl-compound'
      and namespace in [NAMESPACE_TERM, NAMESPACE_TEMPLATE]
    ):
      if 'fi-decl-' in text or 'fi-conj-' in text:
        for match in template_call_regex.finditer(text):
          inflection_type = match.group('inflection_type')
          template_call = match.group('template_call')
          if inflection_type == 'decl':
            # {{fi-decl-kala|kiss|||a}}
            args = [title] + template_call.split('|')
            nominal_declensions.append(args)
          elif inflection_type == 'conj':
            # {{fi-conj-juosta|juo|a}}
            args = [title] + template_call.split('|')
            verb_conjugations.append(args)
      elif '#invoke:fi-nominals|show|' in text:
        template_name = title.split(':').pop()
        kotus_type = text.split('#invoke:fi-nominals|show|').pop().split('}}').pop(0)
        kotus_types_by_template_name[template_name] = kotus_type
      elif '#invoke:fi-verbs|show|' in text:
        template_name = title.split(':').pop()
        kotus_type = text.split('#invoke:fi-verbs|show|').pop().split('}}').pop(0)
        kotus_types_by_template_name[template_name] = kotus_type
    page_data = {}
    page_data_attrib = {}
    # Free parsed elements from memory
    root.clear()
  else:
    page_data[tag_name] = elem.text
    page_data_attrib[tag_name] = elem.attrib

import json
with open('nominal_declensions.json', 'w') as f: json.dump(nominal_declensions, f)
with open('verb_conjugations.json', 'w') as f: json.dump(verb_conjugations, f)
with open('kotus_types_by_template_name.json', 'w') as f: json.dump(kotus_types_by_template_name, f, indent=2)
