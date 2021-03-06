Array.prototype.sortByName = function(){
    if(!this){return;}
    this.sort(function(p1,p2){
        return p1.name.localeCompare(p2.name);
    });
};


Array.prototype.getProperty = function(k){
    var v = new Array();
    this.forEach(function(t){
        var m = t? t[k]:null;
        v.push(m);
    });
    return v;
}

/*
 * 添加Array的remove函数
 */
Array.prototype.remove = function(from, to) {
    if(from < 0 ){
        return ;
    }
    var rest = this.slice((to || from) + 1 || this.length);
    this.length = from < 0 ? this.length + from : from;
    return this.push.apply(this, rest);
};

/*
 * 添加Array的过滤器
 * return 符合条件的对象Array
 */
Array.prototype.filterProperty = function(h, l){
    var g = [];
    this.forEach(function(t){
        var m = t ? t[h]:null;
        var d = false;
        if(m instanceof Array){
            d = m.includes(l);
        }else{
            if(m instanceof Object){
                if("id" in m){
                    m = m["id"];
                }else if("_id" in m){
                    m = m["_id"];
                }

            }
            if(l instanceof Array){
                d = (l === undefined) ? false : l.includes(m);
            }else{
                d = (l === undefined) ? false : m==l;
            }
        }

        if(d){
            g.push(t);
        }
    });
    return g;
}

/*
 * 添加Array的过滤器
 * return 符合条件的第一个对象
 */
Array.prototype.findPropertyByPK = function(h, l){
    var r = null;
    this.forEach(function(t){
        var m = t ? t[h]:null;
        var d = false;
        if(m instanceof Array){
            d = m.includes(l);
        }else{
            d = (l === undefined) ? false : m==l;
        }

        if(d){
            r = t;
        }
    });
    return r;
}