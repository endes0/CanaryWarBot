import db
import json, options, asyncdispatch, strutils, os, random, math, osproc
import telebot
import generateWarMap
import generateMap

proc updateHandler(b: Telebot, u: Update) {.async.} =
  if u.channelPost.isSome and u.channelPost.get.text.isSome and u.channelPost.get.text.get == "chatid":
    var msg = newMessage(u.channelPost.get.chat.id, "id: " & $u.channelPost.get.chat.id)
    b.send(msg)

proc addToSend(b: Telebot, cmd: Command) {.async.} =
    withDb:
      var to = TGToSend(toId: $cmd.message.chat.id)
      if TGToSend.getMany(limit=1, cond="toId='" & $cmd.message.chat.id & "'").len == 0:
        to.insert()
      else:
        var msg = newMessage(cmd.message.chat.id, "BANEADO POR SPAM, nah es una broma.")
        asyncCheck b.send(msg)

proc waitAndQuit(fd: AsyncFD): bool {.gcsafe.} =
  quit(0)

proc poll(bot: TeleBot) =
  try:
    bot.poll(timeout=1800)
  except OSError:
    echo "OS Error: " & getCurrentExceptionMsg()
  except IOError:
    echo "Request Error: " & getCurrentExceptionMsg()
  finally:
    poll()
  
template selText(kind: MessagesKinds): string =
  var all = Messages.getMany(limit=10, cond="kind='" & $kind.int  & "'")
  all[rand(all.len-1)].msg

template process(msg: string, turn: int, munConq: int, conquistado: int): string =
  var fmsg = msg
  fmsg = fmsg.replace("{ano}", $(2020 + (turn/48).trunc.toInt))
  fmsg = fmsg.replace("{semana}", $((turn mod 4)+1))
  fmsg = fmsg.replace("{mes}", $((turn mod 48 / 4).trunc.toInt).Meses)
  fmsg = fmsg.replace("{munConquistador}", Municipe.getOne(munConq).name)
  fmsg = fmsg.replace("{munConquistado}", Municipe.getOne(conquistado).name)
  fmsg
  

proc normalTurn(): tuple[map, txt: string] =
  withDb:
    var playersList = Municipe.getMany(limit=300)
    var player = playersList[rand(playersList.len-1)]
    var realPlayer = if player.conquestedBy != -1: player.conquestedBy else: player.id
    var conquest = playersList[rand(playersList.len-1)]
    var fail = 0
    while true:
      if fail > 100 and player.conquestedBy != -1:
        player = Municipe.getMany(limit=1, cond="conquestedBy='" & $player.conquestedBy & "'")[0]
      let rule = Invadable.getMany(limit=100, cond="who='" & conquest.mapId & "' AND by='" & player.mapId & "'")
      if player.id != conquest.id and player.id != conquest.conquestedBy and rule.len > 0:
        break
      else:
        fail+=1
        conquest = playersList[rand(playersList.len-1)]

    if conquest.conquestedBy == -1 and Municipe.getMany(limit=10, cond="conquestedBy='" & $conquest.id & "'").len < 1:
      result.txt = selText(Defeat)
    elif conquest.conquestedBy != -1 and Municipe.getMany(limit=10, cond="conquestedBy='" & $conquest.conquestedBy & "'").len < 1:
      result.txt = selText(Defeat)
    else:
      result.txt = selText(Normal)

    if Turn.getMany(limit=1, cond="true ORDER BY id ASC").len > 0:
      result.txt = result.txt.process(Turn.getMany(limit=1, cond="true ORDER BY id DESC")[0].id + 2, realPlayer, conquest.id)
    else:
      result.txt = result.txt.process(0,realPlayer, conquest.id)

    var turn = Turn(invaded: conquest.id, by: realPlayer)
    conquest.conquestedBy = realPlayer
    conquest.update()
    turn.insert()

    result.map = generateMap(conquest.mapId, player.mapId)
    
proc superiroInvasionTurn(): tuple[map, txt: string] =
  var ran = rand(30)
  withDb:
    if ran < 10:
      result.txt = selText(Gob)
    elif ran < 20:
      result.txt = selText(Marroc)
    else:
      result.txt = selText(Cat)
    result.txt = result.txt.process(Turn.getMany(limit=1, cond="true ORDER BY id DESC")[0].id + 2, 0, 0)    
    result.map = generateSuperiorMap()

proc independenceTurn(): tuple[map, txt: string] =
  withDb:
    var playersList = Municipe.getMany(limit=300)
    while true:
      var player = playersList[rand(playersList.len-1)]
      if player.conquestedBy != -1:
        var turn = Turn(invaded: player.id, by: player.id)
        result.txt = selText(Independent)
        result.txt = result.txt.process(Turn.getMany(limit=1, cond="true ORDER BY id DESC")[0].id + 2, player.id, player.conquestedBy)
        player.conquestedBy = -1
        player.update()
        turn.insert()
        result.map = generateMap(player.mapId, player.mapId)    
        break
      
      
proc makeTurnHandler(bot: TeleBot) =
  randomize()
  var ran = rand(100)
  var final: tuple[map, txt: string]
  if ran < 85:
    final= normalTurn()
  elif ran < 95:
    final= independenceTurn()
  else:
    final= superiroInvasionTurn()
  
  withDb:
    let toSend = TGToSend.getMany(500)
    for user in toSend:
      discard execCmd "convert -density 300 final.svg target.png"
      var message = newPhoto(user.toId.parseBiggestInt(), "file://" & getCurrentDir() & "/target.png")
      message.caption = final.txt
      discard waitFor bot.send(message)

proc setupGame(map: string, pathsToSkip: seq[string]) =
  withDb:
    createTables(true)

  generate(map, pathsToSkip)

proc setupMap(map: string, pathsToSkip: seq[string]) =
  generate(map, pathsToSkip)
  
proc makeTurn() =
  let API_KEY = readFile("secret.key").strip()
  let bot = newTeleBot(API_KEY)

  bot.onUpdate(updateHandler)
  bot.onCommand("start", addToSend)

  bot.makeTurnHandler()

  addTimer(120000, false, waitAndQuit)
  poll(bot)


when isMainModule:
  import cligen
  dispatchMulti([setupGame], [makeTurn], [generateInvasionMap], [setupMap])