module.exports =

  config:
    extensions:
      title: 'Autoactivated file extensions'
      description: 'list of file extenstions which should have the plugin enabled'
      type: 'array'
      default: [ 'md', 'markdown', 'readme', 'txt', 'rst' ]
      items:
        type: 'string'
    noextension:
      title: 'Autoactivate for files without an extension'
      description: 'plugin enabled for files without a file extension'
      type: 'boolean'
      default: false
      items:
        type: 'boolean'
    doublespace:
      title: 'Double space on carriage return'
      description: 'adds an extra space whenever you press return'
      type: 'boolean'
      default: false

  activate: (state) ->
    atom.workspace.onDidChangeActivePaneItem @checkForStart.bind(@)
    @checkForStart atom.workspace.getActivePaneItem()

  checkForStart: (item) ->
    extensions = (atom.config.get('autocorrect.extensions') || []).map (extension) -> extension.toLowerCase()
    no_extension = atom.config.get('autocorrect.noextension') && item?.buffer?.file?.path.split('.').length == 1
    current_file_extension = item?.buffer?.file?.path.split('.').pop().toLowerCase()
    if no_extension or current_file_extension in extensions
      @start()
    else
      @end()

  punctuation: [' ', '.', '(', ')', ',', ';'],

  start: ->
    body = document.querySelector('body')
    buffer = atom.workspace.getActiveTextEditor().getBuffer()
    @didChange = buffer.onDidChange (event) =>
      if @justChanged
        @justChanged = false
      else if event.newText in @punctuation
        @findWord(event.newRange)
      else if event.newText.charCodeAt(0) is 10 and atom.config.get 'autocorrect-text.doublespace'
        @newLine event.newRange, event.newText.charAt(0)

  end: ->
    @didChange?.dispose()

  newLine: (range, cr) ->
    requestAnimationFrame =>
      buffer = atom.workspace.getActiveTextEditor().getBuffer()
      @justChanged = true
      buffer.transact ->
        buffer.insert range.end, cr

  findWord: (range) ->
    requestAnimationFrame =>
      buffer = atom.workspace.getActiveTextEditor().getBuffer()
      row = range.start.row
      line = buffer.lineForRow(row)
      end = range.start.column - 1
      start = end
      done = false;
      until done or start is 0
        if line[start] in @punctuation
          done = true
          start++
        else
          start--
      word = line.substr start, end - start + 1
      @checkWord word, start, end, row

  isCapital: (letter) ->
    return letter is letter.toUpperCase()

  isLetter: (letter) ->
    code = letter?.charCodeAt(0)
    return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)

  replace: [
    {word: 'adn', replace: 'and'},
    {word: 'hae', replace: 'have'}
    {word: 'i', replace: 'I'},
    {word: "i've", replace: "I've"},
    {word: "i'm", replace: "I'm"},
    {word: "i'd", replace: "I'd"},
    {word: "i'll", replace: "I'll"},
    {word: 'nwo', replace: 'now'},
    {word: 'fo', replace: 'of'},
    {word: 'probaly', replace: 'probably'},
    {word: 'os', replace: 'so'},
    {word: 'somwhere', replace: 'somewhere'},
    {word: 'si', replace: 'is'},
    {word: 'teh', replace: 'the'}
  ]

  checkWord: (word, start, end, row) ->
    buffer = atom.workspace.getActiveTextEditor().getBuffer()
    realStart = buffer.characterIndexForPosition([row, start])
    text = buffer.getText()

    # autocorrect replace
    for words in @replace
      if words.word is word
        @justChanged = true
        buffer.transact ->
          buffer.setTextInRange([[row, start], [row, end + 1]], words.replace)
        break

    # check for double capital (e.g., FRank)
    if word.length > 2
      if @isCapital(word[0]) and @isCapital(word[1]) and not @isCapital(word[2])
        @justChanged = true
        buffer.transact ->
          buffer.setTextInRange([[row, start + 1], [row, start + 2]], word[1].toLowerCase())

    # add period when double space after everything except a punctuation (excluding parentheticals)
    lastTwo = text.substr(realStart - 1, 2)
    twoBack = text[realStart - 2]
    if lastTwo is '  ' and twoBack not in ['.', ',', ';', ' ']
      @justChanged = true
      buffer.transact ->
        buffer.setTextInRange([[row, start - 1], [row, start]], '.')

    # capitalize the first letter of a sentence or the document
    notCapitalized = @isLetter(word[0]) and not @isCapital(word[0])
    if (realStart - 2 is 0 or text.substr(realStart - 2, 2) is '. ') and notCapitalized
      @justChanged = true
      buffer.transact ->
        buffer.setTextInRange([[row, start], [row, start + 1]], word[0].toUpperCase())
