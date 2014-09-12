exec = require('child_process').exec
jf = require 'jsonfile'

ripl =
  path: "./ripl.sh"
  file: "ripl/ripl.json"
dns =
  path: "./subbrute.sh"
  file: "subbrute/dns.json"
http =
  path: ""
  file: ""

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
          console.log my + ' new'
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
          console.log my + ' new'
      start()

startHttp =->
  waitingHosts =
    (host for host in hosts when host.status.http is 'waiting')
  waitingHosts.forEach (host)->
    host.status.http = 'working'
    exec http.path + ' ' + host.name, (err,stdout)->
      host.status.http = stdout
      console.log host.status.http

start =->
  startripl()
  startDns()

start()
