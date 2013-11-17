# -*- coding: utf-8 -*-

import urllib2
import json
import vim


class Hastebin(object):

    URL = "http://hastebin.com"

    @classmethod
    def retrieve(cls, path):
        url = cls.URL + '/raw/' + path
        try:
            rsp = urllib2.urlopen(url)
            vim.command('enew')
            vim.current.buffer[:] = rsp.readlines()
            vim.current.buffer.name = 'hastebin-{}'.format(path)
            vim.command('setlocal buftype=nofile bufhidden=hide noswapfile')
            vim.command('setlocal nomodified')
            vim.command('setlocal nomodifiable')
        except Exception as exc:
            print 'failed to get "{}". error "{}"'.format(url, exc)

    @classmethod
    def paste(cls):
        if all(line.strip() == '' for line in vim.current.buffer):
            print 'empty buffer, abort pasting'
        else:
            print 'pasting to {} ...'.format(cls.URL)
            try:
                rsp = urllib2.urlopen(cls.URL + "/documents",
                                      '\n'.join(vim.current.buffer),
                                      timeout=5).read()
                url = "{}/{}".format(cls.URL, json.loads(rsp)['key'])
                print url
                vim.command('let @+= "{}\n"'.format(url))
            except Exception as exc:
                print type(exc)
                print exc
