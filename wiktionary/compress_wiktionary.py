inflections_data = {
  'current_index': 0,
  'index_mapping': {},
}

with open('wiktionary_inflected_words_cleaned.txt', 'r', newline='\n', encoding='utf-8') as cleaned_word_file, open('wiktionary_words.txt', 'w', newline='\n', encoding='utf-8') as compressed_word_file:
  def get_inflection_index(compressed_inflections):
    key = tuple(compressed_inflections)
    if key in inflections_data['index_mapping']:
      return inflections_data['index_mapping'][key]
    else:
      inflection_index = inflections_data['current_index']
      inflections_data['index_mapping'][key] = inflection_index
      inflections_data['current_index'] += 1
      return inflection_index

  def compress_and_write_inflections(prefixed_word, inflections):
    prefix, word = prefixed_word[0], prefixed_word[1:]
    inflections = [word] + inflections
    partial_word = word
    # This while loop removes one letter at a time from the end of the word,
    # to try to find common letters between the word and its inflections
    while len(partial_word) > 0:
      compressed_inflections = []
      # This for loop removes the partial word from inflections if it can.
      # If it can't it advances the while loop.
      for inflected_word in inflections:
        if not inflected_word.startswith(partial_word):
          break
        split_word = inflected_word.split(partial_word, maxsplit=1).pop()
        compressed_inflections.append(split_word)
      else:
        break
      partial_word = partial_word[:-1]
    inflection_index = get_inflection_index(compressed_inflections)
    compressed_word_file.write(partial_word + '\t' + str(inflection_index) + '\t' + str(len(compressed_inflections)) + '\n')

  inflections = []
  current_word = None
  for line in cleaned_word_file:
    line = line.strip()
    if line.startswith('@') or line.startswith('!'):
      if current_word and inflections:
        compress_and_write_inflections(current_word, inflections)
      current_word = line
      inflections = []
    else:
      inflections.append(line)

with open('wiktionary_inflections.txt', 'w', newline='\n', encoding='utf-8') as inflections_file:
  for inflections, inflection_index in inflections_data['index_mapping'].items():
    inflections_file.write('\t'.join(inflections) + '\n')
