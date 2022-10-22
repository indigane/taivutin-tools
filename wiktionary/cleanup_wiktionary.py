unique_lines = set()

with open('wiktionary_inflected_words.txt', 'r', newline='\n', encoding='utf-8') as word_file, open('wiktionary_inflected_words_cleaned.txt', 'w', newline='\n', encoding='utf-8') as cleaned_word_file:
  def handle_line(line):
    line = line.strip()
    if '<br/>' in line:
      for line in line.split('<br/>'):
        handle_line(line)
    else:
      if '[[' in line:
        line = line.split('[[').pop().split(']]').pop(0)
      if '<' in line:
        line = line.split('<').pop(0)
      if line not in unique_lines:
        unique_lines.add(line)
        if line.startswith('@') or line.startswith('!'):
          unique_lines.add(line.lstrip('@!'))
        cleaned_word_file.write(line + '\n')

  for line in word_file:
    handle_line(line)
