exec = require('child_process').exec
jf = require 'jsonfile'
request = require 'request'
ripl =
  path: "./ripl.sh"
  file: "ripl/ripl.json"
dns =
  path: "./subbrute.sh"
  file: "subbrute/dns.json"

if not process.argv[2]
  console.log 'no host specified'
  return

myhost =
  name: process.argv[2]
  status:
    ripl:'waiting'
    dns:'waiting'
    http:'waiting'

hosts = [myhost]

results = []

###
output =->

  waiting = (host for host in hosts when host.status.ripl is 'waiting').length
  done = (host for host in hosts when host.status.ripl is 'done').length
  working = (host for host in hosts when host.status.ripl is 'working').length
  error = (host for host in hosts when host.status.ripl is 'error').length

  console.log '\u001B[2J\u001B[0;0f'

  console.log 'waiting: ' + waiting
  console.log 'working: ' + working
  console.log 'error: ' + error
  console.log 'done: ' + done

setInterval output,100
###

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
              http:'waiting'
          #console.log my + ' new'
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
  startripl()
  startDns()
  startHttp()

start()
