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
    @buffer = atom.workspace.getActiveTextEditor().getBuffer()
    @didChange = @buffer.onDidChange (event) =>
      if @justChanged
        @justChanged = false
      else if event.newText in @punctuation
        @findWord(event.newRange)

  end: ->
    @didChange?.dispose()

  findWord: (range) ->
    buffer = atom.workspace.getActiveTextEditor().getBuffer()
    row = range.start.row
    line = buffer.lineForRow(row)
    end = range.start.column - 1
    start = end
    while start is not 0 and line[start] in @punctuation
      start--
    word = line.substr start, end - start + 1
    last = line[end + 1]
    @checkWord word, start, end, row, last

  isCapital: (letter) ->
    return letter is letter.toUpperCase()

  replace: [
    {word: 'adn', replace: 'and'},
    {word: 'hae', replace: 'have'}
    {word: 'i', replace: 'I'},
    {word: "i've", replace: "I've"},
    {word: "i'm", replace: "I'm"},
    {word: "i'd", replace: "i'd"},
    {word: 'nwo', replace: 'now'},
    {word: 'fo', replace: 'of'},
    {word: 'probaly', replace: 'probably'},
    {word: 'os', replace: 'so'},
    {word: 'teh', replace: 'the'}
  ]

  checkWord: (word, start, end, row, last) ->
    buffer = atom.workspace.getActiveTextEditor().getBuffer()
    for words in @replace
      if words.word is word
        buffer.setTextInRange([[row, start], [row, end + 1]], words.replace)
        @justChanged = true
        break
    if word.length > 2
      if @isCapital(word[0]) and @isCapital(word[1]) and not @isCapital(word[2])
        buffer.setTextInRange([[row, start + 1], [row, start + 2]], word[1].toLowerCase())
        @justChanged = true
    if word is ' ' and last is ' '
      @justChanged = true
      buffer.setTextInRange([[row, start], [row, start + 1]], '.')
