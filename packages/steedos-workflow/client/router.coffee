checkUserSigned = (context, redirect) ->
	if !Meteor.userId()
		FlowRouter.go '/steedos/sign-in?redirect=' + context.path;


FlowRouter.route '/workflow',
	triggersEnter: [checkUserSigned],
	action: (params, queryParams)->
		$("body").addClass("loading")
		Tracker.autorun (c)->
			if Steedos.subsBootstrap.ready("my_spaces")
				spaceId = Steedos.getSpaceId()
				if spaceId
					$("body").removeClass("loading")
					c.stop();
					FlowRouter.go "/workflow/space/" + spaceId + "/inbox"


workflowSpaceRoutes = FlowRouter.group
	prefix: '/workflow/space/:spaceId',
	name: 'workflowSpace',
	triggersEnter: [checkUserSigned],
# subscriptions: (params, queryParams) ->
# 	if params.spaceId
# 		this.register 'apps', Meteor.subscribe("apps", params.spaceId)
# 		this.register 'space_users', Meteor.subscribe("space_users", params.spaceId)
# 		this.register 'organizations', Meteor.subscribe("organizations", params.spaceId)
# 		this.register 'flow_roles', Meteor.subscribe("flow_roles", params.spaceId)
# 		this.register 'flow_positions', Meteor.subscribe("flow_positions", params.spaceId)

# 		this.register 'categories', Meteor.subscribe("categories", params.spaceId)
# 		this.register 'forms', Meteor.subscribe("forms", params.spaceId)
# 		this.register 'flows', Meteor.subscribe("flows", params.spaceId)


workflowSpaceRoutes.route '/',
	action: (params, queryParams)->
		Steedos.setSpaceId(params.spaceId)
		BlazeLayout.render 'workflowLayout',
			main: "workflow_home"

workflowSpaceRoutes.route '/print/:instanceId',
	action: (params, queryParams)->
		Steedos.setSpaceId(params.spaceId)
		Session.set("instanceId", null);
		Session.set("instance_loading", true);

		console.log "call get_instance_data"

		BlazeLayout.render 'printLayout',
			main: "instancePrint"
		WorkflowManager.callInstanceDataMethod params.instanceId, ()->
			console.log "response get_instance_data"
			Session.set('instancePrint', true);
			Session.set("judge", null);
			Session.set("next_step_id", null);
			Session.set("next_step_multiple", null);
			Session.set("next_user_multiple", null);
			Session.set("instanceId", params.instanceId);
			Session.set("box", queryParams.box);
			Session.set("instance_change", false);
			Session.set("instance_loading", false);
	triggersExit: [(context, redirect) ->
		Session.set('instancePrint', undefined);
	]

workflowSpaceRoutes.route '/:box/',
	action: (params, queryParams)->
		Steedos.setSpaceId(params.spaceId)

		Session.set("box", params.box);
		Session.set("flowId", undefined);
		Session.set("instanceId", null);
		BlazeLayout.render 'workflowLayout',
			main: "workflow_main"

		$(".workflow-main").removeClass("instance-show")

workflowSpaceRoutes.route '/:box/f/:flow',
	action: (params, queryParams)->
		Steedos.setSpaceId(params.spaceId)
		Session.set("box", params.box);
		Session.set("flowId", params.flow)

		BlazeLayout.render 'workflowLayout',
			main: "workflow_main"
	triggersExit: [(context, redirect) ->
		Session.set('flowId', undefined);
	]

workflowSpaceRoutes.route '/:box/:instanceId',
	action: (params, queryParams)->
		Steedos.setSpaceId(params.spaceId)
		Session.set("instanceId", null);
		Session.set("instance_loading", true);

		console.log "call get_instance_data"

		BlazeLayout.render 'workflowLayout',
			main: "workflow_main"

		WorkflowManager.callInstanceDataMethod params.instanceId, ()->
			console.log "response get_instance_data"

			Session.set("judge", null);
			Session.set("next_step_id", null);
			Session.set("next_step_multiple", null);
			Session.set("next_user_multiple", null);
			Session.set("instanceId", params.instanceId);
			Session.set("box", params.box);
			Session.set("instance_change", false);
			Session.set("instance_loading", false);

	triggersExit: [(context, redirect) ->
#		ins发生变化 并且 是传阅  || ins发生变化 并且 表单不是只读
		if Session.get("instance_change") && (InstanceManager.isCC(WorkflowManager.getInstance()) || !ApproveManager.isReadOnly())
			InstanceManager.saveIns();

		Session.set('flow_selected_opinion', undefined);
	]