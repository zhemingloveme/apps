db.space_user_signs = new Meteor.Collection('space_user_signs')


db.space_user_signs._simpleSchema = new SimpleSchema
	space: 
		type: String,
		autoform: 
			type: "hidden",
			defaultValue: ->
				return Session.get("spaceId");
	user:
		type: String,
		autoform: 
			type: "selectuser"

	sign:
		type: String,
		autoform:
			type: 'fileUpload'
			collection: 'avatars'
			accept: 'image/*'

	created:
		type: Date,
		optional: true
	created_by:
		type: String,
		optional: true
	modified:
		type: Date,
		optional: true
	modified_by:
		type: String,
		optional: true

if Meteor.isClient
	db.space_user_signs._simpleSchema.i18n("space_user_signs")

db.space_user_signs.attachSchema db.space_user_signs._simpleSchema;

db.space_user_signs.helpers
	signImage: ()->
		return "<img style='max-width: 120px;max-height: 80px;' src='" + Meteor.absoluteUrl() + "/api/files/avatars/" + this.sign + "' />"

	userName:()->
		user =  SteedosDataManager.spaceUserRemote.findOne({
		            space: this.space,
		            user: this.user
		        }, {
		            fields: {
		              name: 1
		            }
		        });
		return user?.name;

if (Meteor.isServer) 

	db.space_user_signs.before.insert (userId, doc) ->
		doc.created_by = userId;
		doc.created = new Date();
		doc.modified_by = userId;
		doc.modified = new Date();

		userSign = db.space_user_signs.findOne({space: doc.space, user: doc.user});

		if userSign
			throw new Meteor.Error(400, "spaceUserSigns_error_user_sign_exists");

	db.space_user_signs.before.update (userId, doc, fieldNames, modifier, options) ->
		
		modifier.$set.modified_by = userId;
		modifier.$set.modified = new Date();

		if modifier.$set.user
			userSign = db.space_user_signs.findOne({space: doc.space, user: modifier.$set.user, _id:{$ne: doc._id}});

			if userSign
				throw new Meteor.Error(400, "spaceUserSigns_error_user_sign_exists");