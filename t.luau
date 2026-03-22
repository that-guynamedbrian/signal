--!strict
export type function to_string(a:type):type
    local depth = 1
    local recursed = {}
    local typeslist = {} :: {type}
    local typedefs = {}

    local function deep(a:type)
        local tab = ""
        for i = 1, depth-1 do
            tab ..= "    "
        end

        local index:number? = nil
        for i, t in typeslist do
            if t == a then index = i; break end
        end

        if index then
            local n = #typeslist + 1
            recursed[n] = a
            return "t"..index
        elseif a.tag == "table" then  
            local n = #typeslist + 1
            typeslist[n] = a
            depth += 1
            local s = "{"..(next(a:properties()) and "\n" or "") -- only go to next line if non zero
            local s1 = s
            for prop_key, prop_value in a:properties() do
                local value = deep(prop_value.read::type)
                s ..= tab..`    {prop_key:value()}: {value}\n`
                s1 ..= `    {prop_key:value()}: {value}\n`
            end
            s ..= tab .. "}" -- cannot use ..= here
            s1 = s1 .. "}"
            typeslist[n] = nil
            typedefs[n] = if (recursed[n] == nil) then s1 else nil
            s1 ..= "" -- idk why but removing this breaks it
            depth -= 1
            return s
        elseif a.tag == "singleton" then
            return tostring(a:value())
        else
            return a.tag
        end
    end
    
    if a.tag == "singleton" then
        return a::type
    elseif a.tag == "table" then
        deep(a)
        local s = "\nt1 "
        for i, def in pairs(typedefs) do
            s..= `where t{i} = {def} `
        end
        print(s)
        return types.singleton("t1")
    else
        return types.singleton(a.tag)
    end
end

type function doprint(singleton:type)
    print(singleton:value())
    return singleton
end

type classA = {
    a: classA
}

type classB = {
    a: false;
    b: true;
}

type myClass = {
    k1: classA;
    k2: classB;
    other: {
        k3: classA;
        k4: classB;
    };
}

local a: eq<classA, classB>
local c: eq<classA, myClass>
local b: to_string<myClass>

export type function eq(a:type, b:type)
    return types.singleton(a==b)
end

export type function mergetables(intersection:type)
    if intersection.tag ~= "intersection" then
        error(`expected intersection type, got {intersection.tag}`)
    end
    
    local props = {} :: {[type]: {read:type?, write:type?}}
    local indexer = nil
    local metatable = nil
    for _, class in intersection:components() do
        for prop_key, prop_value in class:properties() do
            props[prop_key] = prop_value
        end
        indexer = class:indexer()
        metatable = class:metatable()
    end
    local result = types.newtable(props, indexer, metatable)
    return result
end

export type function typesub_fn(fn:type, tosub:type, subwith:type)
	if fn.tag ~= "function" then
		error("Input must be a function type, received: ".. fn.tag)
	end
    local params = fn:parameters()
    local returns = fn:returns()

    local outparams = {
        head = params.head;
        tail = params.tail == tosub and subwith or params.tail
    }
    local outreturns = {
        head = returns.head;
        tail = returns.tail == tosub and subwith or returns.tail
    }
    for i, type in (params.head or {})::{type} do
        if type == tosub then
            (outparams.head::{type})[i] = subwith
        -- elseif type.tag == "table" then
        --     (outparams.head::{type})[i] = typesub_tbl(type, tosub, subwith)
        -- elseif type.tag == "function" then
        --     (outparams.head::{type})[i] = typesub_fn(type, tosub, subwith)
        end
    end
    for i, type in (returns.head::{type} or {}) do
        if type == tosub then
            (outreturns.head::{type})[i] = subwith
        -- elseif type.tag == "table" then
        --     (outreturns.head::{type})[i] = typesub_tbl(type, tosub, subwith)
        -- elseif type.tag == "function" then
        --     (outreturns.head::{type})[i] = typesub_fn(type, tosub, subwith)
        end 
    end

    return types.newfunction(outparams, outreturns)
end

export type function typesub_tbl(tbl:type, tosub:type, subwith:type)
	if tbl.tag ~= "table" then
		error("Input must be a table type, received: ".. tbl.tag)
	end
    local props = tbl:properties()
    local indexer = tbl:indexer()
    local metatable = tbl:metatable()
    if metatable then
        metatable = typesub_tbl(metatable, tosub, subwith)
    end
    for key, type in indexer or {} do
        if type == tosub then
            (indexer::any)[key] = subwith
        end
    end
    for singleton, pair in props do
        local read = pair.read::type
        if read == tosub then 
            pair.read = subwith
        -- elseif read.tag == "table" then
        --     pair.read = typesub_tbl(read, tosub, subwith)
        elseif read.tag == "function" then
            pair.read = typesub_fn(read, tosub, subwith)
        end

        local write = pair.write::type
        if write == tosub then
            pair.write = subwith
        -- elseif write.tag == "table" then
        --     pair.write = typesub_tbl(write, tosub, subwith)
        elseif write.tag == "function" then 
            pair.write = typesub_fn(write, tosub, subwith)
        end
    end

    return types.newtable(props, indexer, metatable)
end

export type function interface(class:type)
    if class.tag == "intersection" then
        return interface(mergetables(class))
    elseif class.tag ~= "table" then
        error(`expected table type, got {class.tag}`)
    end
    
    local newclass = types.newtable()
    for prop_key, prop_value in class:properties() do
        local true_key = prop_key:value()::string
        if true_key:sub(1,1) == "_" then
            newclass:setproperty(prop_key, nil)
        elseif (prop_value.read::type).tag == "table" then
            newclass:setproperty(prop_key, typesub_tbl(prop_value.read, class, newclass))
        elseif (prop_value.read::type).tag == "function" then
            newclass:setproperty(prop_key, typesub_fn(prop_value.read, class, newclass))
        else
            newclass:setproperty(prop_key, prop_value.read)
        end
    end
    

    local metatable = class:metatable()
    if metatable == nil then return newclass end

    local index = metatable:readproperty(types.singleton("__index"))
    if index and index.tag == "table" then
        for prop_key, prop_value in index:properties() do
            local true_key = prop_key:value()::string
            if true_key:sub(1,1) == "_" then
                index:setproperty(prop_key, nil)
            elseif (prop_value.read::type).tag == "table" then
                index:setproperty(prop_key, typesub_tbl(prop_value.read, class, newclass))
            elseif (prop_value.read::type).tag == "function" then
                index:setproperty(prop_key, typesub_fn(prop_value.read, class, newclass))
            end
        end
    end
    metatable:setproperty(types.singleton("__index"),index)
    newclass:setmetatable(metatable)
    
    
    return newclass
end

export type function optional(opt:type,default:type)
    return opt.tag == "unknown" and default or opt
end

type myClass = {}


return nil