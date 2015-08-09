{CompositeDisposable} = require 'atom'

module.exports =
class AutoCorrectView
  constructor: (@editor) ->
    @disposables = new CompositeDisposable

    @disposables.add @editor.onDidChangePath =>
      @subscribeToBuffer()

    @disposables.add @editor.onDidChangeGrammar =>
      @subscribeToBuffer()

    @disposables.add atom.config.onDidChange 'editor.fontSize', =>
      @subscribeToBuffer()

    @disposables.add atom.config.onDidChange 'spell-check.grammars', =>
      @subscribeToBuffer()

    @subscribeToBuffer()

    @disposables.add @editor.onDidDestroy(@destroy.bind(this))

  destroy: ->
    @unsubscribeFromBuffer()
    @disposables.dispose()
#    @task.terminate()

  unsubscribeFromBuffer: ->
    if @buffer?
      @bufferDisposable.dispose()
      @buffer = null

  subscribeToBuffer: ->
    @unsubscribeFromBuffer()

    @buffer = @editor.getBuffer()
    @bufferDisposable = @buffer.onDidStopChanging => @updateAutocorrect()

  updateAutocorrect:
    if @buffer
      words = @buffer.getText()
      autocorrect(words)

  autocorrect: (words) ->
    console.log(words)