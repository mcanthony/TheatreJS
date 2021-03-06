Foxie = require 'foxie'

module.exports = class Selection

	constructor: (@prop) ->

		@rootView = @prop.rootView

		@timelineEditor = @prop.timelineEditor

		@manager = @timelineEditor.selectionManager

		@_inGroup = no

		@_selecting = no

		@_fromTime = 0
		@_toTime = 0

		@_fromX = 0
		@_toX = 0
		@_selected = no

		@_pacSelection = null

		do @_prepareNode

		do @_prepareHollow

		do @_prepareInteractions

	attach: ->

		@manager.include @

	detach: ->

		@_inGroup = no

		@manager.exclude @

	relayHorizontally: ->

		return unless @_selected

		do @_updateEl

	_prepareNode: ->

		@node = Foxie('.theatrejs-timelineEditor-prop-selection')
		.putIn(@prop.pacsNode)
		.moveX(-5000)

		@leftEdge = Foxie('.theatrejs-timelineEditor-prop-selection-leftEdge')
		.putIn(@node)

		@rightEdge = Foxie('.theatrejs-timelineEditor-prop-selection-rightEdge')
		.putIn(@node)

	_prepareHollow: ->

		@hollow = Foxie('.theatrejs-timelineEditor-prop-selection-hollow')
		.putIn(@prop.pacsNode)
		.moveYTo(-5000)

	_prepareInteractions: ->

		do @_prepareSelectInteraction
		do @_prepareDeselectInteraction
		do @_prepareShiftSelectionInteractions
		do @_prepareModifySelectionInteractions

	_prepareDeselectInteraction: ->

		@_deselectListener = @rootView.moosh.onClick(@prop.node)
		.withNoKeys()
		.disable()
		.onUp =>

			do @_deselect

	_prepareSelectInteraction: ->

		start = 0

		@rootView.moosh.onDrag(@prop.node)
		.withKeys 'shift'
		.onDown (e) =>

			start = e.layerX

			do @_deselect

			do @_startSelecting

			@_selectByLocalX start, start

			@rootView.cursor.use 'ew-resize'

		.onDrag (e) =>

			if e.layerX > start

				@_selectByLocalX start, e.layerX

			else

				@_selectByLocalX e.layerX, start

		.onUp =>

			do @_endSelecting

			@rootView.cursor.free()

		.onCancel =>

			do @_endSelecting

			do @_hide

			@rootView.cursor.free()

	_prepareModifySelectionInteractions: ->

		lastFromX = 0
		lastToX = 0

		@rootView.moosh.onDrag @leftEdge
		.onDown =>

			lastFromX = @_fromX + 1
			lastToX = @_toX - 1

			do @_startSelecting

			@rootView.cursor.use 'ew-resize'

		.onDrag (e) =>

			if lastFromX + e.absX <= lastToX

				@_selectByX lastFromX + e.absX, lastToX

			else

				@_selectByX lastToX, lastFromX + e.absX

		.onUp =>

			do @_endSelecting

			@rootView.cursor.free()

		@rootView.moosh.onDrag @rightEdge
		.onDown =>

			lastFromX = @_fromX + 1
			lastToX = @_toX - 1

			do @_startSelecting

			@rootView.cursor.use 'ew-resize'

		.onDrag (e) =>

			if lastToX + e.absX >= lastFromX

				@_selectByX lastFromX, lastToX + e.absX

			else

				@_selectByX lastToX + e.absX, lastFromX

		.onUp =>

			do @_endSelecting

			@rootView.cursor.free()

		@rootView.moosh.onClick @leftEdge
		.withKeys "super"
		.onDone =>

			@_selectByTime 0, @_toTime

			do @_endSelecting

		@rootView.moosh.onClick @rightEdge
		.withKeys "super"
		.onDone =>

			@_selectByTime @_fromTime, @prop.pacs.timeline.duration

			do @_endSelecting

		@rootView.moosh.onRightClick @node
		.withNoKeys()
		.onDone =>

			do @_showModifySelectionOptions

		@rootView.moosh.onRightClick @node
		.withKeys 'super'
		.onDone =>

			do @_toggleGrouping

	_startSelecting: ->

		@_selecting = yes

		@_pacSelection = null

		do @_show

	_endSelecting: (applyToGroup = yes) ->

		@_selecting = no

		@_selected = yes

		@_pacSelection = @prop.pacs.getSelection @_fromTime, @_toTime

		do @_updateEl

		if applyToGroup and @_inGroup

			for s in @manager.group

				continue if s is @

				s._endSelecting no

		return

	_selectByLocalX: (localFromX, localToX) ->

		@_selectByTime @timelineEditor._XToFocusedTime(localFromX), @timelineEditor._XToFocusedTime(localToX)

	_selectByX: (fromX, toX) ->

		@_selectByTime @timelineEditor._XToTime(fromX), @timelineEditor._XToTime(toX)

	_selectByTime: (@_fromTime, @_toTime, applyToGroup = yes) ->

		do @_updateEl

		if applyToGroup and @_inGroup

			for s in @manager.group

				continue if s is @

				s._selectByTime @_fromTime, @_toTime, no

		return

	_updateEl: ->

		if @_selected is no and @_selecting is no
			@node.moveYTo(-5000)
			return

		@node.moveYTo 0

		if @_pacSelection? and @_pacSelection.empty

			@node.addClass 'empty'

		else

			@node.removeClass 'empty'

		if @_inGroup

			@node.addClass 'inGroup'

		else

			@node.removeClass 'inGroup'

		@_fromX = @timelineEditor._timeToX(@_fromTime) - 1

		@_toX = @timelineEditor._timeToX(@_toTime) + 1

		@node
		.moveXTo(@_fromX)
		.css('width', parseInt(@_toX - @_fromX) + 'px')

	_deselect: (applyToGroup = yes) ->

		@_selected = no

		@_pacSelection = null

		do @_hide

		if applyToGroup and @_inGroup

			for s in @manager.group

				continue if s is @

				s._deselect no

			@manager.closeGroup()

		return

	_hide: ->

		@node.moveYTo(-5000)

		@_deselectListener.disable() if @_deselectListener.enabled

	_show: ->

		@node.moveYTo(0)

		@_deselectListener.enable() unless @_deselectListener.enabled

	_showHollow: ->

		@hollow.moveYTo 0

	_hideHollow: ->

		@hollow.moveYTo -5000

	_resizeHollow: ->

		@hollow
		.css('width', parseInt(@_toX - @_fromX) + 'px')

	_updateHollow: (fromX, toX) ->

		@hollow
		.moveXTo(fromX)

	_prepareShiftSelectionInteractions: ->

		firstDrag = yes

		@rootView.moosh.onDrag @node
		.withNoKeys()
		.onDown (e) =>

			firstDrag = yes

		.onDrag (e) =>

			if firstDrag

				do @_startShifting

				firstDrag = no

			@_shift e.absX

		.onUp =>

			@_endShifting()

		.onCancel =>

			@_cancelShifting()

	_startShifting: (applyToGroup = yes) ->

		@_couldShift = yes

		@rootView.cursor.use 'move'

		do @_resizeHollow

		do @_showHollow

		@node.addClass 'moving'

		if applyToGroup and @_inGroup

			for s in @manager.group

				continue if s is @

				s._startShifting no

		return

	_canShift: (delta) ->

		@_pacSelection.canMoveBy delta

	_shift: (xDelta, applyToGroup = yes) ->

		@_updateHollow @_fromX + xDelta, @_toX + xDelta

		@_lastDelta = @timelineEditor._XToTime xDelta

		if applyToGroup

			@_couldShift = @_canShift @_lastDelta

			if @_inGroup

				for s in @manager.group

					continue if s is @

					@_couldShift = no if s._canShift(@_lastDelta) is no

				for s in @manager.group

					s._couldShift = @_couldShift

					s._shift xDelta, no

		if @_couldShift

			@hollow.removeClass 'bad'

		else

			@hollow.addClass 'bad'

		return

	_endShifting: (applyToGroup = yes) ->

		@rootView.cursor.free()

		do @_hideHollow

		@node.removeClass 'moving'

		if @_couldShift

			@_moveSelection @_lastDelta, no

		if applyToGroup and @_inGroup

			for s in @manager.group

				continue if s is @

				s._endShifting no

		@_lastDelta = 0

		@_couldShift = no

		return

	_cancelShifting: (applyToGroup = yes) ->

		@rootView.cursor.free()

		do @_hideHollow

		@node.removeClass 'moving'

		if applyToGroup and @_inGroup

			for s in @manager.group

				continue if s is @

				s._cancelShifting no

		return

	_showModifySelectionOptions: ->

		@rootView.chooser.choose '', [
			'Fit', 'Copy', 'Delete', 'Repeat', 'Seek to Center', 'Delete Guides',
			'Delete Guides After', 'Delete Guides Before'
			], (success, choice) =>

			return unless success

			switch choice

				when 'Fit'

					do @_fitSelection

				when 'Delete'

					do @_delete

				when 'Repeat'

					do @_askRepeatQuestions

				when 'Seek to Center'

					do @_seekToCenter

				when 'Delete Guides'

					do @_deleteGuides

				when 'Delete Guides After'

					do @_deleteGuidesAfter

				when 'Delete Guides Before'

					do @_deleteGuidesBefore

				when 'Copy'

					do @_copy

	_fitSelection: ->

		@_selectByTime @_pacSelection.realFrom, @_pacSelection.realTo

		do @_endSelecting

	_delete: (applyToGroup = yes) ->

		@_pacSelection.delete()

		@prop.pacs.done()

		if applyToGroup and @_inGroup

			for s in @manager.group

				continue if s is @

				s._delete no

		return

	_copy: (returnIt = no) ->

		if returnIt

			return {

				propName: @prop.propModel.name

				actorName: @prop.propModel.actor.name

				items: @_pacSelection.serialize()

			}

		toCopy = []

		if @_inGroup

			for s in @manager.group

				toCopy.push s._copy yes

		else

			toCopy.push @_copy yes

		@manager.copyToClipboard toCopy

	paste: ->

		@manager.paste @

	_pasteFromClipboard: (items) ->

		@prop.pacs.addMultiple items, @rootView.model.timeControl.t

		@prop.pacs.done()

	_askRepeatQuestions: ->

		@rootView.asker.ask

			question: 'How many?'

			validate: 'number'

			cb: (success, n) =>

				return unless success

				n = parseInt n

				return unless 1 <= n <= 1000

				@rootView.chooser.choose '', ['Connect', 'Dont Connect'], (success, choice) =>

					return unless success

					connect = choice is 'Connect'

					@_repeat n, connect

	_repeat: (n, connect, applyToGroup = yes) ->

		@_pacSelection.repeat n, connect

		@prop.pacs.done()

		if applyToGroup and @_inGroup

			for s in @manager.group

				continue if s is @

				s._repeat n, connect, no

		return

	_seekToCenter: ->

		@timelineEditor.rootView.model.timeControl.tick (@_toTime - @_fromTime) / 2 + @_fromTime

	_deleteGuides: ->

		@timelineEditor.guides.model.removeInRange @_fromTime, @_toTime

	_deleteGuidesAfter: ->

		@timelineEditor.guides.model.removeInRange @_toTime + 1, Infinity

	_deleteGuidesBefore: ->

		@timelineEditor.guides.model.removeInRange 0, @_toTime - 1

	_toggleGrouping: =>

		if @_inGroup

			@manager.takeOffGroup @

		else

			@manager.startGroup @

		do @_updateEl

	_beInGroup: (copyFrom) ->

		if copyFrom?

			do @_deselect

			do @_startSelecting

			@_selectByTime copyFrom._fromTime, copyFrom._toTime

			@_endSelecting no

		@_inGroup = yes

		do @_updateEl

	_beOffGroup: ->

		@_inGroup = no

		do @_updateEl

	_moveSelection: (delta, applyToGroup = yes) ->

		@_pacSelection.moveBy delta

		@_fromTime += delta
		@_toTime += delta

		@prop.pacs.done()

		@_endSelecting no

		if applyToGroup and @_inGroup

			for s in @manager.group

				continue if s is @

				s._moveSelection delta, no

		return