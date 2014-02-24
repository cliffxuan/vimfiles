# -*- coding: utf-8 -*-

import urllib2
import json
import vim


def escape(text):
    return text.replace("'", "''")


def error_msg(text):
    vim.command(
        "echohl ErrorMsg | echo '{}' | echohl None".format(escape(text)))


class Pastebin(object):

    TIMEOUT = 5  # seconds

    @classmethod
    def retrieve(cls, path):
        raise NotImplemented

    @classmethod
    def paste(cls):
        if all(line.strip() == '' for line in vim.current.buffer):
            error_msg('empty buffer, abort pasting')
        else:
            print 'pasting to {} ...'.format(cls.URL)
            try:
                url = cls.paste_impl()
                print url
                vim.command('let @+= "{}\n"'.format(url))
            except Exception as exc:
                print type(exc)
                error_msg(str(exc))

    @classmethod
    def paste_impl(cls):
        raise NotImplemented


class Hastebin(Pastebin):

    URL = "http://hastebin.com"

    @classmethod
    def get_fullpath(cls, path):
        if path.startswith(cls.URL):
            if path.startswith(cls.URL + '/raw'):
                if path == cls.URL + '/raw':
                    raise Exception('wrong url "{}".'.format(path))
                else:
                    return path
            else:
                return cls.URL + '/raw' + path[len(cls.URL):]
        else:
            return '{}/raw/{}'.format(cls.URL, path)

    @classmethod
    def retrieve(cls, path):
        try:
            url = cls.get_fullpath(path)
        except Exception as exc:
            error_msg('{}'.format(exc))
            return
        try:
            rsp = urllib2.urlopen(url, timeout=cls.TIMEOUT)
            vim.command('enew')
            vim.current.buffer[:] = rsp.readlines()
            vim.current.buffer.name = 'hastebin-{}'.format(path)
            vim.command('setlocal bufhidden=hide noswapfile')
            vim.command('setlocal nomodified')
            vim.command('setlocal nomodifiable')
        except Exception as exc:
            error_msg('failed to get "{}". error "{}"'.format(url, exc))

    @classmethod
    def paste_impl(cls):
        rsp = urllib2.urlopen(cls.URL + "/documents",
                              '\n'.join(vim.current.buffer),
                              timeout=cls.TIMEOUT).read()
        url = "{}/{}".format(cls.URL, json.loads(rsp)['key'])
        return url


class Sprunge(Pastebin):

    URL = "http://sprunge.us/"

    @classmethod
    def retrieve(cls, path):
        raise NotImplemented

    @classmethod
    def paste_impl(cls):
        url = urllib2.urlopen(
            cls.URL, 'sprunge={}'.format('\n'.join(vim.current.buffer))).read()
        return url
