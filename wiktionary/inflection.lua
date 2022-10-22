-- Mock MediaWiki lualib
local original_package_path = package.path
package.path = original_package_path .. ';./mediawiki-lualib/?.lua;./mediawiki-lualib/mw.?.lua'
local mw = require('mw')
require('mwInit')
mw.text = require('text')
mw.title = require('title')
local currentTitle = ''
mw.title.getCurrentTitle = function () return currentTitle end
package.path = original_package_path .. ';./mediawiki-lualib/ustring/?.lua'
mw.ustring = require('ustring')
package.loaded['ustring/charsets'] = require('charsets')
package.path = original_package_path

-- Mock Wiktionary modules
local m_utilities = {}
function m_utilities.format_categories(a, b) return '' end
package.loaded['Module:utilities'] = m_utilities

local m_links = {}
function m_links.full_link(data) return data.term end
package.loaded['Module:links'] = m_links

local m_debug = {}
function m_debug.track(text) end
package.loaded['Module:debug'] = m_debug

local lang = {}
function lang.getByCode(a) return lang end
function lang:makeEntryName(a) return a end
package.loaded['Module:languages'] = lang

function template_styles() return '' end
package.loaded['Module:TemplateStyles'] = template_styles

package.loaded['Module:fi-utilities'] = require('wiktionary-modules.fi-utilities')
package.loaded['Module:base64'] = require('wiktionary-modules.base64')


-- Inflection
output_file = io.open('wiktionary_inflected_words.txt', 'w')
function output(inflected_word)
  output_file:write(inflected_word .. '\n')
end

local _orig_gsub = mw.ustring.gsub
function hijack_ustring_gsub()
  local _orig_substitute_function = function(param) return '' end
  function fake_substitute_function(param)
    local result = _orig_substitute_function(param)
    if param ~= 'lemma' and param ~= 'info' and param ~= 'maybenote' and result ~= '&mdash;' then
      output(result)
    end
    return result
  end
  function fake_gsub(template, pattern, substitute_function)
    if type(substitute_function) ~= 'function' then
      return _orig_gsub(template, pattern, substitute_function)
    else
      _orig_substitute_function = substitute_function
      return _orig_gsub(template, pattern, fake_substitute_function)
    end
  end
  mw.ustring.gsub = fake_gsub
end
function unhijack_ustring_gsub()
  mw.ustring.gsub = _orig_gsub
end

function inflect_nominal(title, kotus_type, args)
  currentTitle = title
  local fi_nominals = require('wiktionary-modules.fi-nominals')
  local frame = {}
  frame.args = {kotus_type}
  function frame:getParent()
    local parentFrame = {}
    parentFrame.args = args
    return parentFrame
  end
  output('@' .. title)
  hijack_ustring_gsub()
  result = fi_nominals.show(frame)
  unhijack_ustring_gsub()
  return ''
end

function inflect_verb(title, kotus_type, args)
  currentTitle = title
  local fi_verbs = require('wiktionary-modules.fi-verbs')
  local frame = {}
  frame.args = {kotus_type}
  function frame:getParent()
    local parentFrame = {}
    parentFrame.args = args
    return parentFrame
  end
  output('!' .. title)
  hijack_ustring_gsub()
  result = fi_verbs.show(frame)
  unhijack_ustring_gsub()
  return ''
end
