import db, gamelib/collisions, sdl2, os, streams, parsexml, strutils, sequtils, tables, nre

template skip(pathsToSkip: seq[string], pathName: string): bool = 
    if pathName == "" or pathsToSkip.contains(pathName):
        true
    else:
        false

proc generate*(filename: string, pathsToSkip: seq[string]) =
    echo pathsToSkip
    var s = newFileStream(filename, fmRead)
    var x: XmlParser
    var pol: Table[string, seq[Point]] = initTable[string, seq[Point]](128)
    var cub: Table[string, ref Rect] = initTable[string, ref Rect](128)

    if s == nil: quit("cannot open the file " & filename)
    open(x, s, filename)

    var transform: tuple[x, y: int] = (0, 0)
    var groupDeep = 0
    while true:
        var pol_name = ""
        var temp_pol: seq[Point]
        x.next()
        case x.kind
        of xmlElementOpen:
            if cmpIgnoreCase(x.elementName, "path") == 0:
                x.next()
                while x.kind == xmlAttribute:
                    if cmpIgnoreCase(x.attrKey, "id") == 0:
                        pol_name = x.attrValue
                    elif cmpIgnoreCase(x.attrKey, "d") == 0:
                        for match in x.attrValue.findIter(re"L *(-*[\d.]*),(-*[\d.]*)"):
                            temp_pol.add (x: ((match.captures[0].parseFloat.toInt) + transform.x).cint, y: ((match.captures[1].parseFloat.toInt) + transform.y).cint)
                    
                    x.next()
                if not pathsToSkip.skip(pol_name) and temp_pol.len > 0:
                    echo "Cargado " & pol_name
                    echo transform
                    pol[pol_name] = temp_pol
                    cub[pol_name] = temp_pol.bound()
            elif cmpIgnoreCase(x.elementName, "g") == 0: 
                groupDeep += 1
                x.next()
                while x.kind == xmlAttribute:
                    if cmpIgnoreCase(x.attrKey, "transform") == 0 and x.attrValue.match(re"translate\((-*[\d.]*),(-*[\d.]*)").isSome:
                        let matchs = x.attrValue.match(re"translate\((-*[\d.]*),(-*[\d.]*)").get
                        transform = (x: transform.x + matchs.captures[0].parseFloat.toInt, y: transform.y + matchs.captures[1].parseFloat.toInt)
                    x.next()
        of xmlElementEnd:
            if cmpIgnoreCase(x.elementName, "g") == 0:
                groupDeep += -1
                if groupDeep < 1:
                    transform = (x: 0, y: 0)
                    groupDeep = 0
        of xmlEof: 
            echo "Parsing finish"
            break
        else: discard

    x.close()

    for municipio in pol.keys:
        var cont = pol[municipio]
        var cont_cub = cub[municipio]
        for municipio2 in pol.keys:
            echo "Generando invasiones: " & municipio & " contra " & municipio2 
            if municipio != municipio2 and collides(cont, pol[municipio2]):
                withDb:
                    var disc = Invadable(who: municipio2, by: municipio)
                    disc.insert()
            elif municipio != municipio2:
                var lineP1 = (x: cint(cont_cub.x + (cont_cub.w/2).toInt), y: cint(cont_cub.y + (cont_cub.h/2).toInt))
                var lineP2 = (x: cint(cub[municipio2].x + (cub[municipio2].w/2).toInt), y: cint(cub[municipio2].y + (cub[municipio2].h/2).toInt))

                var cant = false
                for municipio3 in pol.keys:
                    if municipio3 != municipio and municipio3 != municipio2 and intersection(lineP1, lineP2, (x: cint(cub[municipio3].x + (cub[municipio3].w/2).toInt), y: cint(cub[municipio3].y + (cub[municipio3].h/2).toInt)), (cub[municipio3].h/2).toInt).len > 0:
                        #echo municipio3 & "(" & $(x: cint(cub[municipio3].x + (cub[municipio3].w/2).toInt), y: cint(cub[municipio3].y + (cub[municipio3].h/2).toInt)) & ") bloquea " & municipio & "(" & $lineP1 & ") contra " & municipio2 & $lineP2
                        cant = true
                        break
                if not cant:
                    withDb:
                        var disc = Invadable(who: municipio2, by: municipio)
                        disc.insert()
                        
                
        