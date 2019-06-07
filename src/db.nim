import norm/postgres, json
export postgres

var conection = parseFile("conn.json")

type
    MessagesKinds* = enum
       Defeat = 0,
       Normal,
       Independent,
       Gob,
       Marroc,
       Cat

    Meses* = enum
       Enero = 0,
       Febrero,
       Marzo,
       Abril,
       Mayo,
       Junio,
       Julio,
       Agosto,
       Septiembre,
       Octubre,
       Noviembre,
       Diciembre

db(conection["ip"].getStr, conection["user"].getStr, conection["pass"].getStr, conection["DB"].getStr):
    type
        Municipe* = object
            name*: string
            mapId*: string
            color*: string
            population*: int
            conquestedBy*: int
        
        Invadable* = object
            who*: string
            by*: string
        
        Turn* = object
            invaded*: int
            by*: int

        Messages* = object
            kind*: int
            msg*: string
        
        TGToSend* = object
            toId: string
