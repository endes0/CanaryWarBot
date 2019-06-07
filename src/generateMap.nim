import db
import os
import xmlparser, xmltree
import strtabs

import sdl2, nre, tables, gamelib/collisions

proc search(svg: var XmlNode, conquested, color: string) =
    for child in svg.mitems:
        #[if child.kind == xnElement and child.tag == "path" and child.attrs["id"] == "conquestp1":
            child.attrs["fill"] = color
        el]#if child.kind == xnElement and child.tag == "path":
            withDb:
                if conquested == child.attrs["id"]:
                    child.attrs["style"] = "fill:" & color & ";fill-rule:evenodd;stroke:green;stroke-width:5;stroke-linejoin:round;stroke-opacity:1"
                else:   
                    let searchDb = Municipe.getMany(limit=1, cond="mapId='" & child.attrs["id"] & "'")
                    if searchDb.len > 0:
                        if searchDb[0].conquestedBy == -1:
                            child.attrs["style"] = "fill:" & searchDb[0].color & ";fill-rule:evenodd;stroke:black;stroke-width:0.96427435;stroke-linejoin:round;stroke-opacity:1"
                        else:
                            let searchConquester = Municipe.getMany(limit=1, cond="id='" & $searchDb[0].conquestedBy & "'")
                            child.attrs["style"] = "fill:" & searchConquester[0].color & ";fill-rule:evenodd;stroke:black;stroke-width:0.96427435;stroke-linejoin:round;stroke-opacity:1"
        elif child.len > 0:
            search(child, conquested, color) 
                
        
proc search2(svg: var XmlNode) =
    for child in svg.mitems:
        if child.kind == xnElement and child.tag == "path":
            if child.attrs.contains("id"):
                child.attrs["style"] = "fill:#FFD700;fill-rule:evenodd;stroke:black;stroke-width:0.96427435;stroke-linejoin:round;stroke-opacity:1"
                
        elif child.len > 0:
            search2(child) 

proc searchMunicipes(svg: XmlNode, sumx = 0, sumy = 0): Table[string, ref Rect] =
    result = initTable[string, ref Rect]()
    for child in svg.items:
        if child.kind == xnElement and child.tag == "path":
            if child.attrs.contains("id") and child.attrs.contains("d"):
                var points: seq[Point]
                for match in child.attrs["d"].findIter(re"L *([\d.]*),([\d.]*)"):
                    points.add (x: ((match.captures[0].parseFloat.toInt) + sumx).cint, y: ((match.captures[1].parseFloat.toInt) + sumy).cint)
                result[child.attrs["id"]] = bound(points)
                
        elif child.len > 0:
            var x = sumx
            var y = sumy
            if child.kind == xnElement and child.tag == "g" and child.attrs.contains("transform") and child.attrs["transform"].match(re"translate\((-*[\d.]*),(-*[\d.]*)").isSome:
                let matchs = child.attrs["transform"].match(re"translate\((-*[\d.]*),(-*[\d.]*)").get
                x += matchs.captures[0].parseFloat.toInt
                y += matchs.captures[1].parseFloat.toInt
            let muns = searchMunicipes(child, x, y) 
            for mun in muns.keys:
                result[mun] = muns[mun]

        
proc generateMap*(conquested, color: string): string =
    var svg = loadXml(getCurrentDir() & "/map.svg")
    search(svg, conquested, color)
    "final.svg".writeFile($svg)
    return "final.svg"

proc generateSuperiorMap*(): string =
    var svg = loadXml(getCurrentDir() & "/map.svg")
    search2(svg)
    "final.svg".writeFile($svg)
    return "final.svg"
    
proc generateInvasionMap*() =
    var svg = loadXml("../warmap.svg")
    let muns = searchMunicipes(svg)
    withDb:
        var invasions = Invadable.getMany(10000)
        for inv in invasions:
            let byX = muns[inv.by].x + (muns[inv.by].w/2).toInt
            let whoX = muns[inv.who].x + (muns[inv.who].w/2).toInt
            let byY = muns[inv.by].y + (muns[inv.by].h/2).toInt
            let whoY = muns[inv.who].y + (muns[inv.who].h/2).toInt
            svg.add <>line(x1= $byX, x2= $whoX, y1= $byY, y2= $whoY, style="stroke:rgb(255,0,0);stroke-width:1")

    "invasions.svg".writeFile($svg)