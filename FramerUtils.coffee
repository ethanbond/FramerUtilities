#
# Copyright Ethan Bond under Palantir Technologies, Inc.
# 2015
#



F33Utilities =
  isWithin: (a, b) ->
    if a is b then return false
    x = a.x > b.x and (a.x + a.width) < (b.x + b.width)
    y = a.y > b.y and (a.y + a.height) < (b.y + b.height)
    return x and y

  isIntersecting: (a, b) ->
    if a is b then return false
    x = (a.x + a.width) > b.x and (a.x < b.x + b.width)
    y = (a.y + a.height) > b.y and (a.y < b.y + b.height)
    return x and y

  hexToRgb: (hex) ->
    # http://stackoverflow.com/questions/5623838/rgb-to-hex-and-hex-to-rgb
    shorthandRegex = /^#?([a-f\d])([a-f\d])([a-f\d])$/i
    hex = hex.replace shorthandRegex, (m, r, g, b) ->
      r + r + g + g + b + b
    result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec hex
    return {
      r: parseInt result[1], 16
      g: parseInt result[2], 16
      b: parseInt result[3], 16
    }

  stringToRgb: (string) ->
    # For animating with Velocity.js
    string = string.substring string.indexOf('(')+1, string.indexOf(')')
    string = string.split ', '
    frgb =
      r: parseInt string[0]
      g: parseInt string[1]
      b: parseInt string[2]

  colorToChannels: (color) ->
    # For animating with Velocity.js
    if color.r? and color.g? and color.b?
      frgb = color
      frgb.a = if color.a? then color.a else 1
    else if color[0] is '#' and color.length <= 7
      frgb = F33Utilities.hexToRgb color
      frgb.a = 1
    else
      frgb = F33Utilities.stringToRgb color
      frgb.a = 1
      if color.length is 4
        frgb.a = parseFloat color[3]

    channels =
      backgroundColorRed: frgb.r
      backgroundColorGreen: frgb.g
      backgroundColorBlue: frgb.b
      backgroundColorAlpha: frgb.a

    return channels

  centerWithin: (a, b) ->
    dW = Math.abs(b.width - a.width)
    dH = Math.abs(b.height - a.height)
    a.x = b.x + (0.5 * dW)
    a.y = b.y + (0.5 * dH)

  getUltimateParent: (obj) ->
    w = obj
    while w.superLayer? and w.superLayer isnt null then w = w.superLayer
    return w

  hypotenuse: (a, b) ->
    dX = b.x - a.x
    dY = b.y - a.y
    return Math.sqrt(dX * dX + dY * dY)

  getBoundingBox: (obj) ->
    box =
      tl:
        x: obj.x
        y: obj.y
      tr:
        x: obj.x + obj.width
        y: obj.y
      br:
        x: obj.x + obj.width
        y: obj.y + obj.height
      bl:
        x: obj.x
        y: obj.y + obj.height
    return box

  apparentDistance: (a, b, parent) ->
    coordsA = coordsB = null
    if a.superLayer isnt b.superLayer
      if !parent?
        if F33Utilities.getUltimateParent(a) isnt F33Utilities.getUltimateParent(b) then throw new Error "Objects do not have a shared parent layer. Add both of them to Framer root."
        w = F33Utilities.getUltimateParent(a)
      coordsA = relA = F33Utilities.getBoundingBox a
      for coord, value of relA
        coordsA[coord] = Framer.Utils.convertPoint value, a, w
      coordsB = relB = F33Utilities.getBoundingBox b
      for coord, value of relB
        coordsB[coord] = Framer.Utils.convertPoint value, b, w
    else
      coordsA = F33Utilities.getBoundingBox a
      coordsB = F33Utilities.getBoundingBox b

    top2 = coordsA.tl.y
    bottom2 = coordsA.bl.y
    left2 = coordsA.tl.x
    right2 = coordsA.tr.x

    top1 = coordsB.tl.y
    bottom1 = coordsB.bl.y
    left1 = coordsB.tl.x
    right1 = coordsB.tr.x

    radial = 0

    top =  -1 * (bottom1 - top2)
    right =  left1 - right2
    bottom =  top1 - bottom2
    left = -1 * (right1 - left2)

    withinX = left <= 0 and right <= 0
    withinY = top <= 0 and bottom <= 0

    if withinX
      left = left2-left1
      right = -1*(right2-right1)

    if withinY
      top = top2-top1
      bottom = bottom2-bottom1

    res =
      top: top
      right: right
      bottom: bottom
      left: left

    if withinX and not withinY
      res.radial = Math.min(Math.abs(top), Math.abs(bottom))
    else if withinY and not withinX
      res.radial = Math.min(Math.abs(left), Math.abs(right))
    else
      res.radial = Math.sqrt(Math.min(Math.abs(right), Math.abs(left))*Math.min(Math.abs(right), Math.abs(left)) + Math.min(Math.abs(bottom), Math.abs(top))*Math.min(Math.abs(bottom), Math.abs(top)))

    return res

  switchParent: (obj, newParent) ->
    # Switches parent layers without affecting apparent position
    newCoords = Framer.Utils.convertPoint obj, obj.superLayer, newParent
    newParent.addSubLayer obj
    [item.x, item.y] = [newCoords.x, newCoords.y]


class F33Layer extends Layer
  constructor: (@opts) ->
    super(@opts)
    return @
  switchParent: (newParent) ->
    F33Utilities.switchParent @, newParent
    return @
  apparentDistance: (obj, parent) ->
    return F33Utilities.apparentDistance @, obj, parent
  isWithin: (obj) ->
    return F33Utilities.isWithin @, obj
  isIntersecting: (obj) ->
    return F33Utilities.isIntersecting @, obj
  centerWithin: (obj) ->
    F33Utilities.centerWithin @, obj
    return @
  getBoundingBox: () ->
    return F33Utilities.getBoundingBox @
  addSubLayers: (children...) ->
    for child in children
      @addSubLayer child
    return @


class F33Popover
  constructor: (@opts) ->
    @defaultOpts =
      modal: false
      offset: 10
      content: undefined
      pointsTo: undefined
      x: 0
      y: 0
      width: 240
      height: 140
      direction: "right"
      trigger: undefined
      backdropColor: "transparent"

    for k, v of @defaultOpts
      @opts[k] ?= v

    @backdrop = new F33Layer
      x: 0
      y: 0
      width: Canvas.width
      height: Canvas.height
      backgroundColor: @opts.backdropColor

    @backdrop.style.zIndex = 99999
    @popover = new F33Layer
      x: @opts.pointsTo.x + @opts.x
      y: @opts.pointsTo.y + @opts.y
      width: @opts.width
      height: @opts.height
      backgroundColor: "white"
      image: @opts.content

    if @opts.direction is "right" then @popover.x = @popover.x + @opts.pointsTo.width + @opts.offset
    if @opts.direction is "left" then @popover.x = @popover.x - @popover.width - @opts.offset

    @backdrop.addSubLayer @popover
    @addDefaultListeners()

  addDefaultListeners: () ->
    @backdrop.on Events.Click, () =>
      @close()

  close: () ->
    closeAnimation = @backdrop.animate
      properties:
        opacity: 0
      time: 0.2

    closeAnimation.on Events.AnimationEnd, () =>
      @backdrop.destroy()

exports =
  Layer: F33Layer
  Utilities: F33Utilities
  Popover: F33Popover
