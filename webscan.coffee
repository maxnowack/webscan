ripl =
  enabled: false
  path: "./ripl.sh"
  file: "ripl/ripl.json"
dns =
  enabled: false
  path: "./subbrute.sh"
  file: "subbrute/dns.json"
ritx =
  enabled: true
  path: "./ritx.sh"
  file: "RitX/out.txt"

exec = require('child_process').exec
jf = require 'jsonfile'
request = require 'request'
fs = require 'fs'

if not process.argv[2]
  console.log 'no host specified'
  return

myhost =
  name: process.argv[2]
  status:
    ripl:'waiting'
    dns:'waiting'
    ritx:'waiting'
    http:'waiting'

hosts = [myhost]

results = []

startripl =->
  waitingHosts =
    (host for host in hosts when host.status.ripl is 'waiting')
  waitingHosts.forEach (host)->
    host.status.ripl = 'working'
    exec ripl.path + ' ' + host.name, (err,stdout)->
      host.status.ripl = 'done'
      console.log host.name + ' ripl done'
      if err
        host.status.ripl = 'error'
        console.log err
        return
      jf.readFile ripl.file,(err,obj)->
        if obj[0] is null
          return
        obj.forEach (my)->
          cb = (elm)->
            elm.name==my
          if not hosts.some cb
            hosts.push
              name: my
              status:
                ripl:'done'
                dns:'waiting'
                ritx:'waiting'
                http:'waiting'
            #console.log my + ' new'
        start()

startDns =->
  waitingHosts =
    (host for host in hosts when host.status.dns is 'waiting')
  waitingHosts.forEach (host)->
    host.status.dns = 'working'
    exec dns.path + ' ' + host.name, (err,stdout)->
      host.status.dns = 'done'
      console.log host.name + ' dns done'
      if err
        host.status.dns = 'error'
        console.log err
        return
      for my in stdout.split '\n'
        cb = (elm)->
          elm.name==my
        if not hosts.some cb
          hosts.push
            name: my
            status:
              ripl:'waiting'
              dns:'done'
              ritx:'waiting'
              http:'waiting'
          #console.log my + ' new'
      start()

startRitX =->
  waitingHosts =
    (host for host in hosts when host.status.ritx is 'waiting')
  waitingHosts.forEach (host)->
    host.status.ritx = 'working'
    exec ritx.path + ' ' + host.name, (err,stdout)->
      host.status.ritx = 'done'
      console.log host.name + ' ritx done'
      if err
        host.status.ritx = 'error'
        console.log err
        return
      for my in fs.readFileSync(ritx.file,'utf8').split '\n'
        if my.trim() == '' or my.trim().substring(0,1) == '#'
          continue
        cb = (elm)->
          elm.name==my
        if not hosts.some cb
          hosts.push
            name: my
            status:
              ripl:'waiting'
              dns:'waiting'
              ritx:'done'
              http:'waiting'
      start()

startHttp =->
  waitingHosts =
    (host for host in hosts when host.status.http is 'waiting')
  waitingHosts.forEach (host)->
    host.status.http = 'working'
    cb = (err,res,data)->
      if not res
        return
      cb = (elm)->
        elm.url==res.request.uri.href
      if not results.some cb
        newhost =
          url: res.request.uri.href
          error: err
          statusCode: res.statusCode
          headers: res.headers
        results.push newhost
        console.log newhost.url
        jf.writeFileSync 'results.json',results

    request 'http://' + host.name + '/',cb
    request 'https://' + host.name + '/',cb
    host.status.http='done'

start =->
  startripl() if ripl.enabled
  startDns() if dns.enabled
  startRitX() if ritx.enabled
  startHttp()

start()
