fs = require 'fs-extra'

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
    @loadReplacements()
    atom.workspace.onDidChangeActivePaneItem => @checkForStart
    atom.workspace.getActiveTextEditor().onDidChange => @checkForStart
    @checkForStart atom.workspace.getActivePaneItem()
    autocorrect = @
    requestAnimationFrame =>
      return unless spellCheck = atom.packages.getLoadedPackage('spell-check')
      correctionsView = require spellCheck.path + '/lib/corrections-view'
      correctionsView.prototype.confirmed = (correction) ->
        @cancel()
        return unless correction
        buffer = atom.workspace.getActiveTextEditor().getBuffer()
        original = buffer.getTextInRange(@marker.getBufferRange())
        @editor.transact =>
          @editor.selectMarker(@marker)
          newRange = @editor.insertText(correction)
          autocorrect.addToDictionaryPopup original, correction, newRange

  addToDictionary: ->
    return unless @addToDictionaryDecoration
    @addToDictionaryDecoration.destroy()
    @replace[@addToDictionaryOriginal] = @addToDictionaryCorrection
    @saveReplacements()

  addToDictionaryPopup: (original, correction, range) ->
    @addToDictionaryOriginal = original
    @addToDictionaryCorrection = correction
    div = document.createElement('div')
    div.className = 'btn'
    div.innerHTML = 'Add to Autocorrect'
    div.onclick = => @addToDictionary()
    editor = atom.workspace.getActiveTextEditor()
    marker = editor.markBufferRange(range[0])
    @addToDictionaryDecoration = editor.decorateMarker marker, type: 'overlay', item: div, position: 'tail'
    remove = =>
      @addToDictionaryDecoration?.destroy()
    setTimeout remove, 5000

  checkForStart: (item) ->
    extensions = (atom.config.get('autocorrect.extensions') || []).map (extension) -> extension.toLowerCase()
    no_extension = atom.config.get('autocorrect.noextension') && item?.buffer?.file?.path.split('.').length == 1
    current_file_extension = item?.buffer?.file?.path.split('.').pop().toLowerCase()
    if no_extension or current_file_extension in extensions
      @start()
    else
      @end()

  punctuation: [' ', '.', '(', ')', ',', ';', '?', '!'],

  start: ->
    return if @started
    body = document.querySelector('body')
    buffer = atom.workspace.getActiveTextEditor().getBuffer()
    @didChange = buffer.onDidChange (event) =>
      if @justChanged
        @justChanged = false
      else if event.newText in @punctuation
        @findWord(event.newRange)
      else if event.newText.charCodeAt(0) is 10
        @newLine event.newRange, event.newText.charAt(0)
    @started = true

  end: ->
    @didChange?.dispose()
    @started = false

  newLine: (range, cr, doublespace) ->
    requestAnimationFrame =>
      doublespace = atom.config.get 'autocorrect-text.doublespace'
      buffer = atom.workspace.getActiveTextEditor().getBuffer()
      realStart = buffer.characterIndexForPosition([range.end.row, range.end.column])
      text = buffer.getText()
      lastChar = text[realStart - 2]

      # add a period at the end of a paragraph without punctuation
      if lastChar not in ['.', ':', '?', ' ', '!', '"', String.fromCharCode(10)]
        @justChanged = true
        buffer.transact ->
          text = text.substr(0, realStart - 1) + '.' + text.substr(realStart - 1)
          buffer.setText(text)

      # add double spacing when pressing enter (except when proceeded by a blank space)
      if doublespace and lastChar not in [String.fromCharCode(10)]
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
      until done or start <= 0
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

  checkWord: (word, start, end, row) ->
    buffer = atom.workspace.getActiveTextEditor().getBuffer()
    realStart = buffer.characterIndexForPosition([row, start])
    text = buffer.getText()

    # autocorrect replace
    if replace = @replace[word]
        @justChanged = true
        buffer.transact ->
          buffer.setTextInRange([[row, start], [row, end + 1]], replace)

    # check for double capital (e.g., FRank)
    if word.length > 2
      if @isLetter(word[0]) and @isCapital(word[0]) and @isLetter(word[1]) and @isCapital(word[1]) and @isLetter(word[2]) and not @isCapital(word[2])
        @justChanged = true
        buffer.transact ->
          buffer.setTextInRange([[row, start + 1], [row, start + 2]], word[1].toLowerCase())

    # add period when double space after everything except a punctuation (excluding parentheticals)
    lastTwo = text.substr(realStart - 1, 2)
    twoBack = text[realStart - 2]
    if lastTwo is '  ' and twoBack not in ['.', ',', ';', ' ', '?', '!']
      @justChanged = true
      buffer.transact ->
        buffer.setTextInRange([[row, start - 1], [row, start]], '.')

    # capitalize the first letter of a sentence or the document
    notCapitalized = @isLetter(word[0]) and not @isCapital(word[0])
    paragraphStart = text.charCodeAt(realStart - 1) is 10
    if notCapitalized and (realStart - 2 <= 0 or (text[realStart - 1] is ' ' and text[realStart - 2] in ['.', '!', '?']) or paragraphStart)
      @justChanged = true
      buffer.transact ->
        buffer.setTextInRange([[row, start], [row, start + 1]], word[0].toUpperCase())

  loadReplacements: ->
    path = atom.packages.getLoadedPackage('autocorrect-text').path
    fs.readJson path + '/corrections.json', (err, replace) =>
      @replace = replace

  saveReplacements: ->
    path = atom.packages.getLoadedPackage('autocorrect-text').path
    fs.writeJson path + '/corrections.json', @replace