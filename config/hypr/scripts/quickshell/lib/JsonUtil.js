.pragma library

function safeParse(text, fallbackValue) {
    if (fallbackValue === undefined) fallbackValue = ({});
    if (text === undefined || text === null) return fallbackValue;
    try {
        let trimmed = String(text).trim();
        if (trimmed.length === 0) return fallbackValue;
        return JSON.parse(trimmed);
    } catch (err) {
        return fallbackValue;
    }
}

function stringify(value, fallbackText) {
    if (fallbackText === undefined) fallbackText = "{}";
    try {
        return JSON.stringify(value);
    } catch (err) {
        return fallbackText;
    }
}

function get(objectValue, path, fallbackValue) {
    if (fallbackValue === undefined) fallbackValue = undefined;
    if (objectValue === undefined || objectValue === null || !path) return fallbackValue;
    let parts = Array.isArray(path) ? path : String(path).split(".");
    let current = objectValue;
    for (let i = 0; i < parts.length; i++) {
        let key = parts[i];
        if (current === undefined || current === null || current[key] === undefined) return fallbackValue;
        current = current[key];
    }
    return current;
}

function asArray(value) {
    if (Array.isArray(value)) return value;
    if (value === undefined || value === null) return [];
    return [value];
}

function asNumber(value, fallbackValue) {
    if (fallbackValue === undefined) fallbackValue = 0;
    let parsed = Number(value);
    return isNaN(parsed) ? fallbackValue : parsed;
}

function clampNumber(value, minimumValue, maximumValue, fallbackValue) {
    let numberValue = asNumber(value, fallbackValue === undefined ? minimumValue : fallbackValue);
    return Math.max(minimumValue, Math.min(maximumValue, numberValue));
}

function text(value, fallbackValue) {
    if (fallbackValue === undefined) fallbackValue = "";
    if (value === undefined || value === null) return fallbackValue;
    return String(value);
}

function redact(value, replacement) {
    if (replacement === undefined) replacement = "[redacted]";
    if (value === undefined || value === null || String(value).length === 0) return "";
    return replacement;
}

function merge(baseValue, overrideValue) {
    let result = {};
    let key;
    if (baseValue) {
        for (key in baseValue) result[key] = baseValue[key];
    }
    if (overrideValue) {
        for (key in overrideValue) result[key] = overrideValue[key];
    }
    return result;
}
