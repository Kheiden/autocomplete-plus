# This provider is currently experimental.

_ = require 'underscore-plus'
fuzzaldrin = require 'fuzzaldrin'
fuzzaldrinPlus = require 'fuzzaldrin-plus'
{CompositeDisposable}  = require 'atom'
{Selector} = require 'selector-kit'
SymbolStore = require './symbol-store'

module.exports =
class SymbolProvider
  wordRegex: null
  beginningOfLineWordRegex: null
  endOfLineWordRegex: null
  symbolStore: null
  editor: null
  buffer: null
  changeUpdateDelay: 300

  selector: '*'
  inclusionPriority: 0
  suggestionPriority: 0

  watchedBuffers: null

  config: null
  defaultConfig:
    class:
      selector: '.class.name, .inherited-class, .instance.type'
      typePriority: 4
    function:
      selector: '.function.name'
      typePriority: 3
    variable:
      selector: '.variable'
      typePriority: 2
    '':
      selector: '.source'
      typePriority: 1

  constructor: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add(atom.config.observe('autocomplete-plus.enableExtendedUnicodeSupport', (enableExtendedUnicodeSupport) =>
      if enableExtendedUnicodeSupport
        letters = 'A-Za-z\\xAA\\xB5\\xBA\\xC0-\\xD6\\xD8-\\xF6\\xF8-\\u02C1\\u02C6-\\u02D1\\u02E0-\\u02E4\\u02EC\\u02EE\\u0370-\\u0374\\u0376\\u0377\\u037A-\\u037D\\u037F\\u0386\\u0388-\\u038A\\u038C\\u038E-\\u03A1\\u03A3-\\u03F5\\u03F7-\\u0481\\u048A-\\u052F\\u0531-\\u0556\\u0559\\u0561-\\u0587\\u05D0-\\u05EA\\u05F0-\\u05F2\\u0620-\\u064A\\u066E\\u066F\\u0671-\\u06D3\\u06D5\\u06E5\\u06E6\\u06EE\\u06EF\\u06FA-\\u06FC\\u06FF\\u0710\\u0712-\\u072F\\u074D-\\u07A5\\u07B1\\u07CA-\\u07EA\\u07F4\\u07F5\\u07FA\\u0800-\\u0815\\u081A\\u0824\\u0828\\u0840-\\u0858\\u08A0-\\u08B4\\u0904-\\u0939\\u093D\\u0950\\u0958-\\u0961\\u0971-\\u0980\\u0985-\\u098C\\u098F\\u0990\\u0993-\\u09A8\\u09AA-\\u09B0\\u09B2\\u09B6-\\u09B9\\u09BD\\u09CE\\u09DC\\u09DD\\u09DF-\\u09E1\\u09F0\\u09F1\\u0A05-\\u0A0A\\u0A0F\\u0A10\\u0A13-\\u0A28\\u0A2A-\\u0A30\\u0A32\\u0A33\\u0A35\\u0A36\\u0A38\\u0A39\\u0A59-\\u0A5C\\u0A5E\\u0A72-\\u0A74\\u0A85-\\u0A8D\\u0A8F-\\u0A91\\u0A93-\\u0AA8\\u0AAA-\\u0AB0\\u0AB2\\u0AB3\\u0AB5-\\u0AB9\\u0ABD\\u0AD0\\u0AE0\\u0AE1\\u0AF9\\u0B05-\\u0B0C\\u0B0F\\u0B10\\u0B13-\\u0B28\\u0B2A-\\u0B30\\u0B32\\u0B33\\u0B35-\\u0B39\\u0B3D\\u0B5C\\u0B5D\\u0B5F-\\u0B61\\u0B71\\u0B83\\u0B85-\\u0B8A\\u0B8E-\\u0B90\\u0B92-\\u0B95\\u0B99\\u0B9A\\u0B9C\\u0B9E\\u0B9F\\u0BA3\\u0BA4\\u0BA8-\\u0BAA\\u0BAE-\\u0BB9\\u0BD0\\u0C05-\\u0C0C\\u0C0E-\\u0C10\\u0C12-\\u0C28\\u0C2A-\\u0C39\\u0C3D\\u0C58-\\u0C5A\\u0C60\\u0C61\\u0C85-\\u0C8C\\u0C8E-\\u0C90\\u0C92-\\u0CA8\\u0CAA-\\u0CB3\\u0CB5-\\u0CB9\\u0CBD\\u0CDE\\u0CE0\\u0CE1\\u0CF1\\u0CF2\\u0D05-\\u0D0C\\u0D0E-\\u0D10\\u0D12-\\u0D3A\\u0D3D\\u0D4E\\u0D5F-\\u0D61\\u0D7A-\\u0D7F\\u0D85-\\u0D96\\u0D9A-\\u0DB1\\u0DB3-\\u0DBB\\u0DBD\\u0DC0-\\u0DC6\\u0E01-\\u0E30\\u0E32\\u0E33\\u0E40-\\u0E46\\u0E81\\u0E82\\u0E84\\u0E87\\u0E88\\u0E8A\\u0E8D\\u0E94-\\u0E97\\u0E99-\\u0E9F\\u0EA1-\\u0EA3\\u0EA5\\u0EA7\\u0EAA\\u0EAB\\u0EAD-\\u0EB0\\u0EB2\\u0EB3\\u0EBD\\u0EC0-\\u0EC4\\u0EC6\\u0EDC-\\u0EDF\\u0F00\\u0F40-\\u0F47\\u0F49-\\u0F6C\\u0F88-\\u0F8C\\u1000-\\u102A\\u103F\\u1050-\\u1055\\u105A-\\u105D\\u1061\\u1065\\u1066\\u106E-\\u1070\\u1075-\\u1081\\u108E\\u10A0-\\u10C5\\u10C7\\u10CD\\u10D0-\\u10FA\\u10FC-\\u1248\\u124A-\\u124D\\u1250-\\u1256\\u1258\\u125A-\\u125D\\u1260-\\u1288\\u128A-\\u128D\\u1290-\\u12B0\\u12B2-\\u12B5\\u12B8-\\u12BE\\u12C0\\u12C2-\\u12C5\\u12C8-\\u12D6\\u12D8-\\u1310\\u1312-\\u1315\\u1318-\\u135A\\u1380-\\u138F\\u13A0-\\u13F5\\u13F8-\\u13FD\\u1401-\\u166C\\u166F-\\u167F\\u1681-\\u169A\\u16A0-\\u16EA\\u16F1-\\u16F8\\u1700-\\u170C\\u170E-\\u1711\\u1720-\\u1731\\u1740-\\u1751\\u1760-\\u176C\\u176E-\\u1770\\u1780-\\u17B3\\u17D7\\u17DC\\u1820-\\u1877\\u1880-\\u18A8\\u18AA\\u18B0-\\u18F5\\u1900-\\u191E\\u1950-\\u196D\\u1970-\\u1974\\u1980-\\u19AB\\u19B0-\\u19C9\\u1A00-\\u1A16\\u1A20-\\u1A54\\u1AA7\\u1B05-\\u1B33\\u1B45-\\u1B4B\\u1B83-\\u1BA0\\u1BAE\\u1BAF\\u1BBA-\\u1BE5\\u1C00-\\u1C23\\u1C4D-\\u1C4F\\u1C5A-\\u1C7D\\u1CE9-\\u1CEC\\u1CEE-\\u1CF1\\u1CF5\\u1CF6\\u1D00-\\u1DBF\\u1E00-\\u1F15\\u1F18-\\u1F1D\\u1F20-\\u1F45\\u1F48-\\u1F4D\\u1F50-\\u1F57\\u1F59\\u1F5B\\u1F5D\\u1F5F-\\u1F7D\\u1F80-\\u1FB4\\u1FB6-\\u1FBC\\u1FBE\\u1FC2-\\u1FC4\\u1FC6-\\u1FCC\\u1FD0-\\u1FD3\\u1FD6-\\u1FDB\\u1FE0-\\u1FEC\\u1FF2-\\u1FF4\\u1FF6-\\u1FFC\\u2071\\u207F\\u2090-\\u209C\\u2102\\u2107\\u210A-\\u2113\\u2115\\u2119-\\u211D\\u2124\\u2126\\u2128\\u212A-\\u212D\\u212F-\\u2139\\u213C-\\u213F\\u2145-\\u2149\\u214E\\u2183\\u2184\\u2C00-\\u2C2E\\u2C30-\\u2C5E\\u2C60-\\u2CE4\\u2CEB-\\u2CEE\\u2CF2\\u2CF3\\u2D00-\\u2D25\\u2D27\\u2D2D\\u2D30-\\u2D67\\u2D6F\\u2D80-\\u2D96\\u2DA0-\\u2DA6\\u2DA8-\\u2DAE\\u2DB0-\\u2DB6\\u2DB8-\\u2DBE\\u2DC0-\\u2DC6\\u2DC8-\\u2DCE\\u2DD0-\\u2DD6\\u2DD8-\\u2DDE\\u2E2F\\u3005\\u3006\\u3031-\\u3035\\u303B\\u303C\\u3041-\\u3096\\u309D-\\u309F\\u30A1-\\u30FA\\u30FC-\\u30FF\\u3105-\\u312D\\u3131-\\u318E\\u31A0-\\u31BA\\u31F0-\\u31FF\\u3400-\\u4DB5\\u4E00-\\u9FD5\\uA000-\\uA48C\\uA4D0-\\uA4FD\\uA500-\\uA60C\\uA610-\\uA61F\\uA62A\\uA62B\\uA640-\\uA66E\\uA67F-\\uA69D\\uA6A0-\\uA6E5\\uA717-\\uA71F\\uA722-\\uA788\\uA78B-\\uA7AD\\uA7B0-\\uA7B7\\uA7F7-\\uA801\\uA803-\\uA805\\uA807-\\uA80A\\uA80C-\\uA822\\uA840-\\uA873\\uA882-\\uA8B3\\uA8F2-\\uA8F7\\uA8FB\\uA8FD\\uA90A-\\uA925\\uA930-\\uA946\\uA960-\\uA97C\\uA984-\\uA9B2\\uA9CF\\uA9E0-\\uA9E4\\uA9E6-\\uA9EF\\uA9FA-\\uA9FE\\uAA00-\\uAA28\\uAA40-\\uAA42\\uAA44-\\uAA4B\\uAA60-\\uAA76\\uAA7A\\uAA7E-\\uAAAF\\uAAB1\\uAAB5\\uAAB6\\uAAB9-\\uAABD\\uAAC0\\uAAC2\\uAADB-\\uAADD\\uAAE0-\\uAAEA\\uAAF2-\\uAAF4\\uAB01-\\uAB06\\uAB09-\\uAB0E\\uAB11-\\uAB16\\uAB20-\\uAB26\\uAB28-\\uAB2E\\uAB30-\\uAB5A\\uAB5C-\\uAB65\\uAB70-\\uABE2\\uAC00-\\uD7A3\\uD7B0-\\uD7C6\\uD7CB-\\uD7FB\\uF900-\\uFA6D\\uFA70-\\uFAD9\\uFB00-\\uFB06\\uFB13-\\uFB17\\uFB1D\\uFB1F-\\uFB28\\uFB2A-\\uFB36\\uFB38-\\uFB3C\\uFB3E\\uFB40\\uFB41\\uFB43\\uFB44\\uFB46-\\uFBB1\\uFBD3-\\uFD3D\\uFD50-\\uFD8F\\uFD92-\\uFDC7\\uFDF0-\\uFDFB\\uFE70-\\uFE74\\uFE76-\\uFEFC\\uFF21-\\uFF3A\\uFF41-\\uFF5A\\uFF66-\\uFFBE\\uFFC2-\\uFFC7\\uFFCA-\\uFFCF\\uFFD2-\\uFFD7\\uFFDA-\\uFFDC'
        @wordRegex = RegExp "[#{letters}\\d_]*[#{letters}}_-]+[#{letters}}\\d_]*(?=[^#{letters}\\d_]|$)", 'g'
        @beginningOfLineWordRegex = RegExp "^[#{letters}\\d_]*[#{letters}_-]+[#{letters}\\d_]*(?=[^#{letters}\\d_]|$)", 'g'
        @endOfLineWordRegex = RegExp "[#{letters}\\d_]*[#{letters}_-]+[#{letters}\\d_]*$", 'g'
      else
        @wordRegex = /\b\w*[a-zA-Z_-]+\w*\b/g
        @beginningOfLineWordRegex = /^\w*[a-zA-Z_-]+\w*\b/g
        @endOfLineWordRegex = /\b\w*[a-zA-Z_-]+\w*$/g
    ))
    @watchedBuffers = new WeakMap
    @symbolStore = new SymbolStore(@wordRegex)
    @subscriptions.add(atom.config.observe('autocomplete-plus.minimumWordLength', (@minimumWordLength) => ))
    @subscriptions.add(atom.config.observe('autocomplete-plus.includeCompletionsFromAllBuffers', (@includeCompletionsFromAllBuffers) => ))
    @subscriptions.add(atom.config.observe('autocomplete-plus.useAlternateScoring', (@useAlternateScoring) => ))
    @subscriptions.add(atom.config.observe('autocomplete-plus.useLocalityBonus', (@useLocalityBonus) => ))
    @subscriptions.add(atom.workspace.observeActivePaneItem(@updateCurrentEditor))
    @subscriptions.add(atom.workspace.observeTextEditors(@watchEditor))

  dispose: =>
    @subscriptions.dispose()

  watchEditor: (editor) =>
    buffer = editor.getBuffer()
    editorSubscriptions = new CompositeDisposable
    editorSubscriptions.add editor.displayBuffer.onDidTokenize =>
      @buildWordListOnNextTick(editor)
    editorSubscriptions.add editor.onDidDestroy =>
      index = @getWatchedEditorIndex(editor)
      editors = @watchedBuffers.get(editor.getBuffer())
      editors.splice(index, 1) if index > -1
      editorSubscriptions.dispose()

    if bufferEditors = @watchedBuffers.get(buffer)
      bufferEditors.push(editor)
    else
      bufferSubscriptions = new CompositeDisposable
      bufferSubscriptions.add buffer.onWillChange ({oldRange, newRange}) =>
        editors = @watchedBuffers.get(buffer)
        if editors and editors.length and editor = editors[0]
          @symbolStore.removeTokensInBufferRange(editor, oldRange)
          @symbolStore.adjustBufferRows(editor, oldRange, newRange)

      bufferSubscriptions.add buffer.onDidChange ({newRange}) =>
        editors = @watchedBuffers.get(buffer)
        if editors and editors.length and editor = editors[0]
          @symbolStore.addTokensInBufferRange(editor, newRange)

      bufferSubscriptions.add buffer.onDidDestroy =>
        @symbolStore.clear(buffer)
        bufferSubscriptions.dispose()
        @watchedBuffers.delete(buffer)

      @watchedBuffers.set(buffer, [editor])
      @buildWordListOnNextTick(editor)

  isWatchingEditor: (editor) ->
    @getWatchedEditorIndex(editor) > -1

  isWatchingBuffer: (buffer) ->
    @watchedBuffers.get(buffer)?

  getWatchedEditorIndex: (editor) ->
    if editors = @watchedBuffers.get(editor.getBuffer())
      editors.indexOf(editor)
    else
      -1

  updateCurrentEditor: (currentPaneItem) =>
    return unless currentPaneItem?
    return if currentPaneItem is @editor
    @editor = null
    @editor = currentPaneItem if @paneItemIsValid(currentPaneItem)

  buildConfigIfScopeChanged: ({editor, scopeDescriptor}) ->
    unless @scopeDescriptorsEqual(@configScopeDescriptor, scopeDescriptor)
      @buildConfig(scopeDescriptor)
      @configScopeDescriptor = scopeDescriptor

  buildConfig: (scopeDescriptor) ->
    @config = {}
    legacyCompletions = @settingsForScopeDescriptor(scopeDescriptor, 'editor.completions')
    allConfigEntries = @settingsForScopeDescriptor(scopeDescriptor, 'autocomplete.symbols')

    # Config entries are reverse sorted in order of specificity. We want most
    # specific to win; this simplifies the loop.
    allConfigEntries.reverse()

    for {value} in legacyCompletions
      @addLegacyConfigEntry(value) if Array.isArray(value) and value.length

    addedConfigEntry = false
    for {value} in allConfigEntries
      if not Array.isArray(value) and typeof value is 'object'
        @addConfigEntry(value)
        addedConfigEntry = true

    @addConfigEntry(@defaultConfig) unless addedConfigEntry

  addLegacyConfigEntry: (suggestions) ->
    suggestions = ({text: suggestion, type: 'builtin'} for suggestion in suggestions)
    @config.builtin ?= {suggestions: []}
    @config.builtin.suggestions = @config.builtin.suggestions.concat(suggestions)

  addConfigEntry: (config) ->
    for type, options of config
      @config[type] ?= {}
      @config[type].selectors = Selector.create(options.selector) if options.selector?
      @config[type].typePriority = options.typePriority ? 1
      @config[type].wordRegex = @wordRegex

      suggestions = @sanitizeSuggestionsFromConfig(options.suggestions, type)
      @config[type].suggestions = suggestions if suggestions? and suggestions.length
    return

  sanitizeSuggestionsFromConfig: (suggestions, type) ->
    if suggestions? and Array.isArray(suggestions)
      sanitizedSuggestions = []
      for suggestion in suggestions
        if typeof suggestion is 'string'
          sanitizedSuggestions.push({text: suggestion, type})
        else if typeof suggestions[0] is 'object' and (suggestion.text? or suggestion.snippet?)
          suggestion = _.clone(suggestion)
          suggestion.type ?= type
          sanitizedSuggestions.push(suggestion)
      sanitizedSuggestions
    else
      null

  uniqueFilter: (completion) -> completion.text

  paneItemIsValid: (paneItem) ->
    # TODO: remove conditional when `isTextEditor` is shipped.
    if typeof atom.workspace.isTextEditor is "function"
      atom.workspace.isTextEditor(paneItem)
    else
      return false unless paneItem?
      # Should we disqualify TextEditors with the Grammar text.plain.null-grammar?
      paneItem.getText?

  ###
  Section: Suggesting Completions
  ###

  getSuggestions: (options) =>
    prefix = options.prefix?.trim()
    return unless prefix?.length and prefix?.length >= @minimumWordLength
    return unless @symbolStore.getLength()

    @buildConfigIfScopeChanged(options)

    {editor, prefix, bufferPosition} = options
    numberOfWordsMatchingPrefix = 1
    wordUnderCursor = @wordAtBufferPosition(editor, bufferPosition)
    for cursor in editor.getCursors()
      continue if cursor is editor.getLastCursor()
      word = @wordAtBufferPosition(editor, cursor.getBufferPosition())
      numberOfWordsMatchingPrefix += 1 if word is wordUnderCursor

    buffer = if @includeCompletionsFromAllBuffers then null else @editor.getBuffer()
    symbolList = @symbolStore.symbolsForConfig(@config, buffer, wordUnderCursor, numberOfWordsMatchingPrefix)

    words =
      if atom.config.get("autocomplete-plus.strictMatching")
        symbolList.filter((match) -> match.text?.indexOf(options.prefix) is 0)
      else
        @fuzzyFilter(symbolList, @editor.getBuffer(), options)

    for word in words
      word.replacementPrefix = options.prefix

    return words

  wordAtBufferPosition: (editor, bufferPosition) ->
    lineToPosition = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    prefix = lineToPosition.match(@endOfLineWordRegex)?[0] or ''
    lineFromPosition = editor.getTextInRange([bufferPosition, [bufferPosition.row, Infinity]])
    suffix = lineFromPosition.match(@beginningOfLineWordRegex)?[0] or ''
    prefix + suffix

  fuzzyFilter: (symbolList, buffer, {bufferPosition, prefix}) ->
    # Probably inefficient to do a linear search
    candidates = []

    if @useAlternateScoring
      fuzzaldrinProvider = fuzzaldrinPlus
      # This allows to pre-compute and re-use some quantities derived from prefix such as
      # Uppercase, lowercase and a version of prefix without optional characters.
      prefixCache = fuzzaldrinPlus.prepQuery(prefix)
    else
      fuzzaldrinProvider = fuzzaldrin
      prefixCache = null

    for symbol in symbolList
      text = (symbol.snippet or symbol.text)
      continue unless text and prefix[0].toLowerCase() is text[0].toLowerCase() # must match the first char!
      score = fuzzaldrinProvider.score(text, prefix, prefixCache)
      if @useLocalityBonus then score *= @getLocalityScore(bufferPosition, symbol.bufferRowsForBuffer?(buffer))
      candidates.push({symbol, score}) if score > 0

    candidates.sort(@symbolSortReverseIterator)

    results = []
    for {symbol, score}, index in candidates
      break if index is 20
      results.push(symbol)
    results

  symbolSortReverseIterator: (a, b) -> b.score - a.score

  getLocalityScore: (bufferPosition, bufferRowsContainingSymbol) ->
    if bufferRowsContainingSymbol?
      rowDifference = Number.MAX_VALUE
      rowDifference = Math.min(rowDifference, bufferRow - bufferPosition.row) for bufferRow in bufferRowsContainingSymbol
      locality = @computeLocalityModifier(rowDifference)
      locality
    else
      1

  computeLocalityModifier: (rowDifference) ->
    rowDifference = Math.abs(rowDifference)
    if @useAlternateScoring
      # Between 1 and 1 + strength. (here between 1.0 and 2.0)
      # Avoid a pow and a branching max.
      # 25 is the number of row where the bonus is 3/4 faded away.
      # strength is the factor in front of fade*fade. Here it is 1.0
      fade = 25.0 / (25.0 + rowDifference)
      1.0 + fade * fade
    else
      # Will be between 1 and ~2.75
      1 + Math.max(-Math.pow(.2 * rowDifference - 3, 3) / 25 + .5, 0)

  settingsForScopeDescriptor: (scopeDescriptor, keyPath) ->
    atom.config.getAll(keyPath, scope: scopeDescriptor)

  ###
  Section: Word List Building
  ###

  buildWordListOnNextTick: (editor) =>
    _.defer => @buildSymbolList(editor)

  buildSymbolList: (editor) =>
    return unless editor?.isAlive()
    @symbolStore.clear(editor.getBuffer())
    @symbolStore.addTokensInBufferRange(editor, editor.getBuffer().getRange())

  # FIXME: this should go in the core ScopeDescriptor class
  scopeDescriptorsEqual: (a, b) ->
    return true if a is b
    return false unless a? and b?

    arrayA = a.getScopesArray()
    arrayB = b.getScopesArray()

    return false if arrayA.length isnt arrayB.length

    for scope, i in arrayA
      return false if scope isnt arrayB[i]
    true
