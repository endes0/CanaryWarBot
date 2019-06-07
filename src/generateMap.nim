import db
import os
import xmlparser, xmltree
import strtabs

import sdl2, nre, tables, gamelib/collisions


proc search(svg: var XmlNode, colorTable: StringTableRef, strokeTable: StringTableRef, extract = false, sumx = 0, sumy = 0): Table[string, seq[Point]] =
    result = initTable[string, seq[Point]]()
    for child in svg.mitems:
        if child.kind == xnElement and child.tag == "path":
            if colorTable.hasKey(child.attrs["id"]) and strokeTable.hasKey(child.attrs["id"]):
                child.attrs["style"] = "fill:" & colorTable[child.attrs["id"]] & ";fill-rule:evenodd;stroke:" & strokeTable[child.attrs["id"]] & ";stroke-width:5;stroke-linejoin:round;stroke-opacity:1"
            elif colorTable.hasKey(child.attrs["id"]):
                child.attrs["style"] = "fill:" & colorTable[child.attrs["id"]] & ";fill-rule:evenodd;stroke:black;stroke-width:0.96427435;stroke-linejoin:round;stroke-opacity:1"

            if extract and child.attrs.contains("d"):
                var points: seq[Point]
                for match in child.attrs["d"].findIter(re"L *([\d.]*),([\d.]*)"):
                    points.add (x: ((match.captures[0].parseFloat.toInt) + sumx).cint, y: ((match.captures[1].parseFloat.toInt) + sumy).cint)
                result[child.attrs["id"]] = points
        if extract and child.kind == xnElement and child.tag == "g" and child.attrs.contains("transform") and child.attrs["transform"].match(re"translate\((-*[\d.]*),(-*[\d.]*)").isSome:
                let matchs = child.attrs["transform"].match(re"translate\((-*[\d.]*),(-*[\d.]*)").get
                var x = sumx + matchs.captures[0].parseFloat.toInt
                var y = sumy + matchs.captures[1].parseFloat.toInt
                let extracted = search(child, colorTable, strokeTable, extract, x, y)
                for pol in extracted.keys:
                    result.add(pol, extracted[pol])
        elif child.len > 0:
            if extract:
                let extracted = search(child, colorTable, strokeTable, true)
                for pol in extracted.keys:
                    result.add(pol, extracted[pol])
            else:
                discard search(child, colorTable, strokeTable)
        
proc generateMap*(conquested, conquestor: string): string =
    var svg = loadXml(getCurrentDir() & "/map.svg")
    var colorTable = newStringTable()
    var strokeTable = {conquested: "red", conquestor:"green"}.newStringTable()

    withDb:
        for conquestor in Municipe.getMany(limit=300, cond="conquestedBy='-1'"):
            colorTable[conquestor.mapId] = conquestor.color
        for conquested in Municipe.getMany(limit=300, cond="conquestedBy>'-1'"):
            colorTable[conquested.mapId] = Municipe.getMany(limit=1, cond="id='" & $conquested.conquestedBy & "'")[0].color

    discard search(svg, colorTable, strokeTable)
    "final.svg".writeFile($svg)
    return "final.svg"

proc generateSuperiorMap*(): string =
    var svg = loadXml(getCurrentDir() & "/map.svg")
    var colorTable = newStringTable()

    withDb:
        for mun in Municipe.getMany(limit=500):
            colorTable[mun.mapId] = "#FFD700"

    discard search(svg, colorTable, newStringTable())
    "final.svg".writeFile($svg)
    return "final.svg"
    
proc generateInvasionMap*() =
    var svg = loadXml(getCurrentDir() & "/map.svg")
    let munsPol = search(svg, newStringTable(), newStringTable(), true)
    var muns = initTable[string, ref Rect]()
    for mun in munsPol.keys:
        muns[mun] = munsPol[mun].bound()
    withDb:
        var invasions = Invadable.getMany(10000)
        for inv in invasions:
            let byX = muns[inv.by].x + (muns[inv.by].w/2).toInt
            let whoX = muns[inv.who].x + (muns[inv.who].w/2).toInt
            let byY = muns[inv.by].y + (muns[inv.by].h/2).toInt
            let whoY = muns[inv.who].y + (muns[inv.who].h/2).toInt
            svg.add <>line(x1= $byX, x2= $whoX, y1= $byY, y2= $whoY, style="stroke:rgb(255,0,0);stroke-width:1")

    writeFile("invasions.svg", $svg)