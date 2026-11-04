local configuredLocale = tostring(GetConvar('ox:locale', '')):lower()
if configuredLocale == '' or configuredLocale == 'pt' then configuredLocale = 'pt-br' end
if configuredLocale == 'en-us' then configuredLocale = 'en' end

if type(lib) == 'table' and type(lib.locale) == 'function' then
  local ok = pcall(lib.locale, configuredLocale)
  if not ok and configuredLocale ~= 'en' then pcall(lib.locale, 'en') end
end

function MZJobsText(key, fallback, ...)
  if type(locale) == 'function' then
    local ok, value = pcall(locale, key, ...)
    if ok and type(value) == 'string' and value ~= key then return value end
  end
  return fallback or key
end
