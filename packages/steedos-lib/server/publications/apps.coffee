if Meteor.isServer
    Meteor.publish 'apps', (spaceId)->
        unless this.userId
            return this.ready()
        
        console.log '[publish] apps ' + spaceId

        selector = {space: {$exists: false}}
        if spaceId
            selector = {$or: [{space: {$exists: false}}, {space: spaceId}]}
        
        return db.apps.find(selector, {sort: {sort: 1, space_sort: 1}});
