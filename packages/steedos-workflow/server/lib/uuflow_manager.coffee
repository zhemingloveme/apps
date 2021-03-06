uuflowManager = {}

uuflowManager.getInstance = (instance_id) ->
	ins = db.instances.findOne(instance_id)
	if not ins
		throw new Meteor.Error('error!', "instance_id有误或此instance已经被删除")
	return ins

uuflowManager.getSpace = (space_id) ->
	space = db.spaces.findOne(space_id)
	if not space
		throw new Meteor.Error('error!', "space_id有误或此space已经被删除")
	return space

uuflowManager.getSpaceUser = (space_id, user_id) ->
	space_user = db.space_users.findOne({space: space_id, user: user_id})
	if not space_user
		throw new Meteor.Error('error!', "user_id对应的用户不属于当前space")
	return space_user

uuflowManager.getFlow = (flow_id) ->
	flow = db.flows.findOne(flow_id)
	if not flow
		throw new Meteor.Error('error!', "flow_id有误或此flow已经被删除")
	return flow

uuflowManager.getSpaceUserOrgInfo = (space_user) ->
	info = new Object
	info.organization = space_user.organization
	org = db.organizations.findOne(space_user.organization)
	info.organization_name = org.name
	info.organization_fullname = org.fullname
	return info

uuflowManager.getTrace = (instance, trace_id) ->
	trace = _.find(instance.traces, (t)->
		return t._id is trace_id
	)
	if not trace
		throw new Meteor.Error('error!', "trace_id有误")
	return trace

uuflowManager.getApprove = (trace, approve_id) ->
	approve = _.find(trace.approves, (t)->
		return t._id is approve_id
	)
	if not approve
		throw new Meteor.Error('error!', "trace_id有误")
	return approve

uuflowManager.isTraceNotFinished = (trace) ->
	if trace.is_finished isnt false
		throw new Meteor.Error('error!', "可能已有人对此文件做了处理。请点击已审核，查看文件的最新状态")
	return

uuflowManager.isApproveNotFinished = (approve) ->
	if approve.is_finished != false
		throw new Meteor.Error('error!', "approve不为未完成状态,不能进行此操作")
	return

uuflowManager.isInstancePending = (instance) ->
	if instance.state isnt "pending"
		throw new Meteor.Error('error!', "instance不为pending状态,不能进行此操作")
	return

uuflowManager.isHandlerOrAgent = (approve, user_id) ->
	return

uuflowManager.isInstanceDraft = (instance, lang="zh-CN") ->
	if instance.state isnt "draft"
		throw new Meteor.Error('error!', TAPi18n.__('instance.remindMessage.update_failed',{},lang))

uuflowManager.isInstanceSubmitter = (instance, current_user_id) ->
	if instance.submitter isnt current_user_id
		throw new Meteor.Error('error!', '当前用户不是申请单对应的提交人,不能进行此操作')

uuflowManager.isInstanceSubmitterOrApplicantOrSpaceAdmin = (instance, current_user_id, space)->
	if instance.submitter isnt current_user_id and instance.applicant isnt current_user_id && not space.admins.includes(current_user_id)
		throw new Meteor.Error('error!', "当前用户不是申请单对应的提交人或申请人或工作区管理员")

uuflowManager.getStep = (instance, flow, step_id) ->
	flow_rev = instance.flow_version
	isExistStep = null
	if flow.current._id is flow_rev
		isExistStep = _.find(flow.current.steps, (step)->
				return step._id is step_id
			)
	else
		_.each(flow.historys, (history)->
				if history._id is flow_rev
					isExistStep = _.find(history.steps, (step)->
							return step._id is step_id
						)
			)

	if not isExistStep
		throw new Meteor.Error('error!', "不能获取step")

	return isExistStep

uuflowManager.isJudgeLegal = (judge) ->
	if judge isnt "approved" and judge isnt "rejected"
		throw new Meteor.Error('error!', "judge有误")
	return

uuflowManager.isSpaceAdmin = (space_id, user_id) ->
	space = db.spaces.findOne(space_id)
	if not space.admins.includes(user_id)
		throw new Meteor.Error('error!', "当前用户不是工作区管理员,不能进行此操作")
	return

uuflowManager.getUser = (user_id) ->
	user = db.users.findOne(user_id)
	if not user
		throw new Meteor.Error('error!', "用户ID有误或此用户已经被删除")
	return user

uuflowManager.getUserOrganization = (user_id, space_id) ->
  org = db.organizations.findOne({space: space_id, users: user_id})
  return org

uuflowManager.getUserRoles = (user_id, space_id) ->
	role_names = new Array
	positions = db.flow_positions.find({space: space_id, users: user_id}).fetch()
	_.each(positions, (position)->
		role = db.flow_roles.findOne(position.role)
		if role
			role_names.push(role.name)
	)
	return role_names

uuflowManager.isFlowEnabled = (flow)->
	if flow.state isnt "enabled"
		throw new Meteor.Error('error!', "流程未启用,操作失败")

uuflowManager.isFlowSpaceMatched = (flow, space_id)->
	if flow.space isnt space_id
		throw new Meteor.Error('error!', "流程和工作区ID不匹配")

# 当前节点为条件节点类型时，根据条件计算出后续步骤
uuflowManager.calculateCondition = (values, condition_str) ->
	try
		__values = values

		sum = (subform_field) ->
			if not subform_field
				throw new Meteor.Error('error!', "参数为空")
			if not subform_field instanceof Array
				throw new Meteor.Error('error!', "参数不是数组类型")
			sum_field_value = 0
			_.each(subform_field, (field_value)->
				field_value = Number(String(field_value))
				sum_field_value += field_value
			)
			return sum_field_value

		average = (subform_field) ->
			if not subform_field
				throw new Meteor.Error('error!', "参数为空")
			if not subform_field instanceof Array
				throw new Meteor.Error('error!', "参数不是数组类型")
			return sum(subform_field)/count(subform_field)

		count = (subform_field) ->
			if not subform_field
				throw new Meteor.Error('error!', "参数为空")
			subform_field.length

		max = (subform_field) ->
			if not subform_field
				throw new Meteor.Error('error!', "参数为空")
			if not subform_field instanceof Array
				throw new Meteor.Error('error!', "参数不是数组类型")
			sub_field = new Array
			_.each(subform_field, (field_value)->
				sub_field.push(Number(String(field_value)))
			)
			return _.max(sub_field)

		min = (subform_field) ->
			if not subform_field
				throw new Meteor.Error('error!', "参数为空")
			if not subform_field instanceof Array
				throw new Meteor.Error('error!', "参数不是数组类型")
			sub_field = new Array
			_.each(subform_field, (field_value)->
				sub_field.push(Number(String(field_value)))
			)
			return _.min(sub_field)

		eval(condition_str)
	catch e
		console.error e.stack
		return false


# 代码结构
# 子表
#   数值
#   字符
# 选组
#   多选
#   单选
# 选人
#   多选
#   单选
# 数值
# 字符
uuflowManager.setFormFieldVariable = (fields, __values, space_id) ->
	try
		_.each(fields, (field)->
			if field.type is "table" #子表
				#得到已引用的子表字段
				subform_fields_all = field.fields
				_subform_values = new Object
				_.each(subform_fields_all, (current_field)->
					values_arr = new Array
					if ["number", "percentage", "currency"].includes(current_field["type"])
						_.each(__values[field.code], (sub_field)->
							values_arr.push(sub_field[current_field["code"]])
						)
					else if current_field["type"] is "checkbox"
						_.each(__values[field.code], (sub_field)->
							if sub_field[current_field["code"]] is "true"
								values_arr.push(true)
							else if sub_field[current_field["code"]] is "false"
								values_arr.push(false)
						)
					else
						_.each(__values[field.code], (sub_field)->
							if sub_field[current_field["code"]]
								values_arr.push(sub_field[current_field["code"]])
							else
								values_arr.push("")
						)

					__values[current_field["code"]] = values_arr
				)
			else if field.type is "group" #选组
				if field.is_multiselect
					if __values[field.code] and __values[field.code].length > 0
						group_id = new Array
						group_name = new Array
						group_fullname = new Array
						_.each(__values[field.code], (group)->
							group_id.push(group["id"])
							group_name.push(group["name"])
							group_fullname.push(group["fullname"])
						)
						__values[field.code] = new Object
						__values[field.code]["id"] = group_id
						__values[field.code]["name"] = group_name
						__values[field.code]["fullname"] = group_fullname
			else if field.type is "user" #选人
				if field.is_multiselect
					if __values[field.code] and __values[field.code].length > 0
						user_id = new Array
						user_name = new Array
						organization = new Object
						organization["user_organization_fullname"] = new Array
						organization["user_organization_name"] = new Array
						user_roles = new Array

						_.each(__values[field.code], (select_user)->
							user_id.push(select_user["id"])
							user_name.push(select_user["name"])
							organization_selectuser = uuflowManager.getUserOrganization(select_user["id"], space_id)
							role_selectuser = uuflowManager.getUserRoles(select_user["id"],space_id)
							if organization_selectuser
								organization["user_organization_fullname"].push(organization_selectuser.fullname)
								organization["user_organization_name"].push(organization_selectuser.name)
							if role_selectuser
								user_roles = user_roles or role_selectuser
						)

						__values[field.code] = new Object
						__values[field.code]["id"] = user_id
						__values[field.code]["name"] = user_name
						__values[field.code]["organization"] = organization
						__values[field.code]["roles"] = roles
				else
					if __values[field.code]
						organization_selectuser = uuflowManager.getUserOrganization(__values[field.code]["id"],space_id)
						role_selectuser = uuflowManager.getUserRoles(__values[field.code]["id"],space_id)
						if organization_selectuser
							__values[field.code]["organization"] = new Object
							__values[field.code]["organization"]["fullname"] = organization_selectuser.fullname
							__values[field.code]["organization"]["name"] = organization_selectuser.name

						__values[field.code]["roles"] = role_selectuser

			else if ["number", "percentage", "currency"].includes(field.type) #数值类型
				if __values[field.code]
					__values[field.code] = Number(__values[field.code])
				else
					__values[field.code] = 0
			else if field.type is "checkbox" #勾选框
				if __values[field.code] is "true"
					__values[field.code] = true
				else if __values[field.code] is "false"
					__values[field.code] = false
		)
	catch e
		console.error e.stack

# 应用场景：此函数用于返回备选的所有下一步的id
uuflowManager.getNextSteps = (instance, flow, step, judge) ->
	step_type = step.step_type
	nextSteps = new Array
	if step_type is "condition"
		#step的lines中查询出state=submitted且instance.fields满足其条件的line
		__values = uuflowManager.getUpdatedValues(instance)
		current_approve = null
		# 获取当前Approve
		traces = instance.traces
		_.each(traces, (trace)->
			if trace.step is step._id and trace.is_finished is false
				current_approve = trace.approves[0]
		)

		start_approve = null
		# 获取开始节点Approve
		_.each(traces, (trace)->
			if not trace.previous_trace_ids or trace.previous_trace_ids.length is 0
				start_approve = trace.approves[0]
		)

		# 申请人所在组织全名称
		applicant_organization_fullname = instance.applicant_organization_fullname
		# 申请人所在组织的名称
		applicant_organization_name = instance.applicant_organization_name
		# 申请人的审批岗位
		applicant_roles = uuflowManager.getUserRoles(instance.applicant, instance.space)
		# 申请人的全名
		applicant_name = instance.applicant_name
		# 填单人所在组织全名称
		submitter_organization_fullname = start_approve.handler_organization_fullname
		# 填单人所在组织的名称
		submitter_organization_name = start_approve.handler_organization_name
		# 填单人的审批岗位 
		submitter_roles = uuflowManager.getUserRoles(start_approve.handler, instance.space)
		# 填单人的全名
		submitter_name = start_approve.handler_name
		# 处理人所在组织全名称
		approver_organization_fullname = current_approve.handler_organization_fullname
		# 处理人所在组织的名称
		approver_organization_name = current_approve.handler_organization_name
		# 处理人的审批岗位
		approver_roles = uuflowManager.getUserRoles(current_approve.handler, instance.space)
		# 处理人的全名
		approver_name = current_approve.handler_name

		# Condition中涉及的一些变量
		__values["applicant"] = new Object
		__values["applicant"]["roles"] = applicant_roles
		__values["applicant"]["name"] = applicant_name
		__values["applicant"]["organization"] = new Object
		__values["applicant"]["organization"]["fullname"] = applicant_organization_fullname
		__values["applicant"]["organization"]["name"] = applicant_organization_name

		__values["submitter"] = new Object
		__values["submitter"]["roles"] = submitter_roles
		__values["submitter"]["name"] = submitter_name
		__values["submitter"]["organization"] = new Object
		__values["submitter"]["organization"]["fullname"] = submitter_organization_fullname
		__values["submitter"]["organization"]["name"] = submitter_organization_name

		__values["approver"] = new Object
		__values["approver"]["roles"] = approver_roles
		__values["approver"]["name"] = approver_name
		__values["approver"]["organization"] = new Object
		__values["approver"]["organization"]["fullname"] = approver_organization_fullname
		__values["approver"]["organization"]["name"] = approver_organization_name

		# 获取申请单对应表单
		form = db.forms.findOne(instance.form)
		formVersion = null
		if instance.form_version is form.current._id
			formVersion = form.current
		else
			formVersion = _.find(form.historys, (history)->
				return instance.form_version is history._id
			)

		# 定义表单中字段
		uuflowManager.setFormFieldVariable(formVersion.fields, __values, instance.space)
		# 匹配包括花括号自身在内的所有符号
		reg = /(\{[^{}]*\})/
		prefix = "__values"
		_.each(step.lines, (step_line)->
			step_line_condition = step_line.condition.replace(reg, (vowel)->
				return prefix + vowel.replace(/\{\s*/,"[\"").replace(/\s*\}/,"\"]").replace(/\s*\.\s*/g,"\"][\"")
				if step_line.state is "submitted" and uuflowManager.calculateCondition(__values, step_line_condition)
					if step_line.state is "submitted"
						nextSteps.push(step_line.to_step)
			)

		)

	else if step_type is "end"
		return new Array
	else if step_type is "submit" or step_type is "start" or step_type is "counterSign"
		lines = _.filter(step.lines, (line)->
			return line.state is "submitted"
		)
		if lines.length is 0
			throw new Meteor.Error('error!', "流程的连线配置有误")
		else
			nextSteps = _.pluck(lines, 'to_step')
	else if step_type is "sign"
		if judge is "approved"
			lines = _.filter(step.lines, (line)->
				return line.state is "approved"
			)
			if lines.length is 0
				throw new Meteor.Error('error!', "流程的连线配置有误")
			else
				nextSteps = _.pluck(lines, 'to_step')
		else if judge is "rejected"
			lines = _.filter(step.lines, (line)->
				return line.state is "rejected"
			)
			rejectedSteps = _.pluck(lines, 'to_step')
			# 取出instance的traces,取出所有历史trace中(is_finished=ture)的step_id
			trace_steps = new Array
			_.each(instance.traces, (trace)->
				if trace.is_finished is true
					flowVersions = new Array
					flowVersions.push(flow.current)
					if flow.historys
						flowVersions = flowVersions.concat(flow.historys)
					_.each(flowVersions, (flowVer)->
						if flowVer._id is instance.flow_version
							_.each(flowVer.steps, (flow_ver_step)->
								if flow_ver_step._id is trace.step and flow_ver_step.step_type isnt "condition"
									trace_steps.push(trace.step)
							)
					)
			)
			# 取出flow,取到instance对应的版本的开始结点和结束结点的step_id
			flow_steps = new Array
			if instance.flow_version is flow.current._id
				_.each(flow.current.steps, (flow_step)->
					if flow_step.step_type is "start" or flow_step.step_type is "end"
						flow_steps.push(flow_step._id)
				)
			else
				_.each(flow.historys, (history)->
					_.each(history.steps, (history_step)->
						if history_step.step_type is "start" or history_step.step_type is "end"
							flow_steps.push(history_step._id)
					)
				)

			nextSteps = _.union(rejectedSteps, trace_steps, flow_steps)

	# 若下一步中包含 条件节点 则 继续取得 条件节点的 后续步骤
	version_steps = new Object
	flowVersions = new Array
	flowVersions.push(flow.current)
	if flow.historys
		flowVersions = flowVersions.concat(flow.historys)

	_.each(flowVersions, (flowVer)->
		if flowVer._id is instance.flow_version
			_.each(flowVer.steps, (flow_ver_step)->
				version_steps[flow_ver_step._id] = flow_ver_step
			)
	)

	nextSteps = _.uniq(nextSteps)
	_.each(nextSteps, (next_step_id)->
		_next_step = version_steps[next_step_id]
		if _next_step.step_type is "condition"
			if _next_step.lines
				_.each(_next_step.lines, (line)->
					if line.to_step
						nextSteps.push(line.to_step)
				)
	)

	nextSteps = _.uniq(nextSteps)
	return nextSteps

uuflowManager.getUpdatedValues = (instance) ->

	# 取得最新的approve
	trace_approve = null
	_.each(instance.traces, (trace)->
		if trace.is_finished is false
			trace_approve = _.find(trace.approves, (approve)->
				return approve.is_finished is false
			)
	)
	# 取得最新的values
	newest_values = null
	if not instance.values
		newest_values = trace_approve.values
	else if not trace_approve.values
		newest_values = instance.values
	else
	  newest_values = _.extend(instance.values, trace_approve.values)
	return newest_values

uuflowManager.getForm = (form_id) ->
	form = db.forms.findOne(form_id)
	if not form
		throw new Meteor.Error('error!', '表单ID有误或此表单已经被删除') 

	return form

uuflowManager.getInstanceName = (instance) ->
	values = instance.values || {}
	form_id = instance.form
	flow = uuflowManager.getFlow(instance.flow)

	default_value = flow.name + ' ' + instance.code
	name_forumla = uuflowManager.getForm(form_id).current.name_forumla
	rev = default_value

	if name_forumla
		iscript = name_forumla.replace(/\{/g,"values['").replace(/\}/g,"']")
		rev = eval(iscript) || default_value

	return rev.trim()

uuflowManager.getApproveValues = (approve_values, permissions, form_id, form_version) ->
	# 如果permissions为null，则approve_values为{}
	if permissions is null
		approve_values = new Object
	else
		# 获得instance中的所有字段
		instance_form = db.forms.findOne(form_id)
		form_v = null
		if form_version is instance_form.current._id
			form_v = instance_form.current
		else
			form_v = _.find(instance_form.historys, (form_h)->
					return form_version is form_h._id
				)

			_.each(form_v.fields, (field)->
				if field.type is "table"
					_.each(field.fields, (tableField)->
						if approve_values[field.code] isnt null
							_.each(approve_values[field.code], (tableValue)->
								if permissions[tableField.code] is null or permissions[tableField.code] isnt "editable"
									delete tableValue[tableField.code]
							)
					)
				else if field.type is "section"
					_.each(field.fields, (sectionField)->
						if permissions[sectionField.code] is null or permissions[sectionField.code] isnt "editable"
							delete approve_values[sectionField.code]
					)
				else
					if permissions[field.code] is null or permissions[field.code] isnt "editable"
						delete approve_values[field.code]
			)
	return approve_values

uuflowManager.engine_step_type_is_start_or_submit_or_condition = (instance_id, trace_id, approve_id, next_steps, space_user_org_info, judge, instance, flow, step, current_user, current_user_info) ->
	setObj = new Object
	space_id = instance.space
	# 验证next_steps.step是否合法
	nextSteps = uuflowManager.getNextSteps(instance, flow, step, "")
	# 判断next_steps.step是否在nextSteps中,若不在则不合法
	_.each next_steps, (approve_next_step) ->
		if not nextSteps.includes approve_next_step["step"]
			throw new Meteor.Error('error!', "approve中next_steps.step："+approve_next_step.step+" 不合法")

	# 若合法,执行流转
	next_step_id = next_steps[0]["step"]
	next_step = uuflowManager.getStep(instance, flow, next_step_id)
	next_step_type = next_step.step_type
	# 判断next_step是否为结束结点
	if next_step_type is "end"
		# 若是结束结点
		instance_traces = instance.traces
		i = 0 
		while i < instance_traces.length
			if instance_traces[i]._id is trace_id
				# 更新当前trace记录
				instance_traces[i].is_finished = true
				instance_traces[i].finish_date = new Date
				instance_traces[i].judge = judge
				h = 0
				while h < instance_traces[i].approves.length
					if instance_traces[i].approves[h]._id is approve_id
						# 更新当前trace.approve记录
						instance_traces[i].approves[h].is_finished = true
						instance_traces[i].approves[h].handler = current_user
						instance_traces[i].approves[h].handler_name = current_user_info.name
						instance_traces[i].approves[h].finish_date = new Date
						instance_traces[i].approves[h].handler_organization = space_user_org_info["organization"]
						instance_traces[i].approves[h].handler_organization_name = space_user_org_info["organization_name"]
						instance_traces[i].approves[h].handler_organization_fullname = space_user_org_info["organization_fullname"]
						# 调整approves 的values 。删除values中在当前步骤中没有编辑权限的字段值
						instance_traces[i].approves[h].values = uuflowManager.getApproveValues(instance_traces[i].approves[h].values, step["permissions"], instance.form, instance.form_version)
					h++
			i++

		# 插入下一步trace记录
		newTrace = new Object
		newTrace._id = new Mongo.ObjectID()._str
		newTrace.instance = instance_id
		newTrace.previous_trace_ids = [trace_id]
		newTrace.is_finished = true
		newTrace.step = next_step_id
		newTrace.start_date = new Date
		newTrace.finish_date = new Date
		newTrace.due_date = if next_step.timeout_hours then (new Date+(60*60*next_step.timeout_hours))
		
		# 更新instance记录
		setObj.state = "completed"
		setObj.modified = new Date
		setObj.modified_by = current_user
		setObj.values = uuflowManager.getUpdatedValues(uuflowManager.getInstance(instance_id))
		instance.values = setObj.values
		setObj.name = uuflowManager.getInstanceName(instance)

		instance_trace = _.find(instance_traces, (trace)->
			return trace._id is trace_id
		)
		trace_approve = _.find(instance_trace.approves, (approve)->
			return approve._id is approve_id
		)
		outbox_users = instance.outbox_users
		outbox_users = outbox_users.unshift(trace_approve.handler)
		outbox_users = outbox_users.unshift(trace_approve.user)
		setObj.outbox_users = _.uniq(outbox_users)

		instance_traces.push(newTrace)
		setObj.traces = instance_traces
		setObj.inbox_users=[]
	else
		# 若不是结束结点
		# 先判断nextsteps.step.users是否为空
		next_step_users = next_steps[0]["users"]
		if next_step_users is null or next_step_users.length is 0
			throw new Meteor.Error('error!', "未指定下一步处理人")
		else
			if next_step_users.length > 1 and next_step.step_type isnt "counterSign"
				throw new Meteor.Error('error!', "不能指定多个处理人")
			else
				# 验证next_user是否合法，调用getHandlersManager.getHandlers(:instance_id,当前trace对应的step_id),判断next_user是否在其返回的结果中
				next_user_ids = getHandlersManager.getHandlers(instance_id, next_step_id)
				if _.difference(next_step_users, next_user_ids).length > 0
					throw new Meteor.Error('error!', "指定的下一步处理人有误")
				else
					# 若合法，执行流转操作
					instance_traces = instance.traces
					i = 0 
					while i < instance_traces.length
						if instance_traces[i]._id is trace_id
							# 更新当前trace记录
							instance_traces[i].is_finished = true
							instance_traces[i].finish_date = new Date
							instance_traces[i].judge = judge
							h = 0
							while h < instance_traces[i].approves.length
								if instance_traces[i].approves[h]._id is approve_id
									# 更新当前trace.approve记录
									instance_traces[i].approves[h].is_finished = true
									instance_traces[i].approves[h].handler = current_user
									instance_traces[i].approves[h].handler_name = current_user_info.name
									instance_traces[i].approves[h].finish_date = new Date
									instance_traces[i].approves[h].handler_organization = space_user_org_info["organization"]
									instance_traces[i].approves[h].handler_organization_name = space_user_org_info["organization_name"]
									instance_traces[i].approves[h].handler_organization_fullname = space_user_org_info["organization_fullname"]
									# 调整approves 的values 。删除values中在当前步骤中没有编辑权限的字段值
									instance_traces[i].approves[h].values = uuflowManager.getApproveValues(instance_traces[i].approves[h].values, step["permissions"], instance.form, instance.form_version)
								h++
						i++

					# 插入下一步trace记录
					newTrace = new Object
					newTrace._id = new Mongo.ObjectID()._str
					newTrace.instance = instance_id
					newTrace.previous_trace_ids = [trace_id]
					newTrace.is_finished = false
					newTrace.step = next_step_id
					newTrace.start_date = new Date
					newTrace.approves = new Array
					_.each next_step_users, (next_step_user_id)->
						# 插入下一步trace.approve记录
						newApprove = new Object
						newApprove._id = new Mongo.ObjectID()._str
						newApprove.instance = instance_id
						newApprove.trace = newTrace._id
						newApprove.is_finished = false
						newApprove.user = next_step_user_id

						handler_info = db.users.findOne(next_step_user_id)
						newApprove.user_name = handler_info.name
						newApprove.handler = next_step_user_id
						newApprove.handler_name = handler_info.name

						next_step_space_user = db.space_users.findOne({space: space_id, user: next_step_user_id})
						# 获取next_step_user所在的部门信息
						next_step_user_org_info = uuflowManager.getSpaceUserOrgInfo(next_step_space_user)
						newApprove.handler_organization = next_step_user_org_info["organization"]
						newApprove.handler_organization_name = next_step_user_org_info["organization_name"]
						newApprove.handler_organization_fullname = next_step_user_org_info["organization_fullname"]
						newApprove.start_date = new Date
						newApprove.is_read = false
						newApprove.is_error = false
						newApprove.values = new Object
						newTrace.approves.push(newApprove)

					# 更新instance记录
					setObj.modified = new Date
					setObj.modified_by = current_user
					setObj.values = uuflowManager.getUpdatedValues(uuflowManager.getInstance(instance_id))
					instance.values = setObj.values
					setObj.name = uuflowManager.getInstanceName(instance)

					instance_trace = _.find(instance_traces, (trace)->
						return trace._id is trace_id
					)
					trace_approve = _.find(instance_trace.approves, (approve)->
						return approve._id is approve_id
					)
					outbox_users = instance.outbox_users
					outbox_users.unshift(trace_approve.user)
					outbox_users.unshift(trace_approve.handler)
					setObj.outbox_users = _.uniq(outbox_users)
					setObj.inbox_users = next_step_users

					instance_traces.push(newTrace)
					setObj.traces = instance_traces
	
	return setObj

uuflowManager.engine_step_type_is_sign = (instance_id, trace_id, approve_id, next_steps, space_user_org_info, judge, instance, flow, step, current_user, current_user_info, description) ->
	setObj = new Object
	space_id = instance.space
	# 验证approve的judge是否为空

	if not judge
		throw new Meteor.Error('error!', "单签结点还未选择处理意见，操作失败")
	else
		if judge is "approved"
			# 验证next_steps.step是否合法,判断next_steps.step是否在其中
			nextSteps = uuflowManager.getNextSteps(instance, flow, step, "approved")

			# 判断next_steps.step是否在nextSteps中,若不在则不合法
			_.each(next_steps, (approve_next_step)->
				if not nextSteps.includes(approve_next_step["step"])
					throw new Meteor.Error('error!', "指定的下一步有误")
			)
			# 若合法,执行流转
			next_step_id = next_steps[0]["step"]
			next_step = uuflowManager.getStep(instance, flow, next_step_id)
			next_step_type = next_step["step_type"]
			# 判断next_step是否为结束结点
			if next_step_type is "end"
				# 若是结束结点
				instance_traces = instance.traces
				i = 0 
				while i < instance_traces.length
					if instance_traces[i]._id is trace_id
						# 更新当前trace记录
						instance_traces[i].is_finished = true
						instance_traces[i].finish_date = new Date
						instance_traces[i].judge = judge
						h = 0
						while h < instance_traces[i].approves.length
							if instance_traces[i].approves[h]._id is approve_id
								# 更新当前trace.approve记录
								instance_traces[i].approves[h].is_finished = true
								instance_traces[i].approves[h].handler = current_user
								instance_traces[i].approves[h].handler_name = current_user_info.name
								instance_traces[i].approves[h].finish_date = new Date
								instance_traces[i].approves[h].handler_organization = space_user_org_info["organization"]
								instance_traces[i].approves[h].handler_organization_name = space_user_org_info["organization_name"]
								instance_traces[i].approves[h].handler_organization_fullname = space_user_org_info["organization_fullname"]
							h++
					i++

				# 插入下一步trace记录
				newTrace = new Object
				newTrace._id = new Mongo.ObjectID()._str
				newTrace.instance = instance_id
				newTrace.previous_trace_ids = [trace_id]
				newTrace.is_finished = true
				newTrace.step = next_step_id
				newTrace.start_date = new Date
				newTrace.finish_date = new Date
				newTrace.due_date = if next_step.timeout_hours then (new Date+(60*60*next_step.timeout_hours))
				
				# 更新instance记录
				setObj.state = "completed"
				setObj.final_decision = judge
				setObj.modified = new Date
				setObj.modified_by = current_user
				setObj.values = uuflowManager.getUpdatedValues(uuflowManager.getInstance(instance_id))
				instance.values = setObj.values
				setObj.name = uuflowManager.getInstanceName(instance)

				instance_trace = _.find(instance_traces, (trace)->
					return trace._id is trace_id
				)
				trace_approve = _.find(instance_trace.approves, (approve)->
					return approve._id is approve_id
				)
				outbox_users = instance.outbox_users
				outbox_users.unshift(trace_approve.handler)
				outbox_users.unshift(trace_approve.user)
				setObj.outbox_users = _.uniq(outbox_users)
				instance_traces.push(newTrace)
				setObj.traces = instance_traces
				setObj.inbox_users = []
			else
				# 若不是结束结点
				# 先判断nextsteps.step.users是否为空
				next_step_users = next_steps[0]["users"]
				if next_step_users is null or next_step_users.length is 0
					throw new Meteor.Error('error!', "未指定下一步处理人")
				else
					if next_step_users.length > 1 and next_step["step_type"] isnt "counterSign"
						throw new Meteor.Error('error!', "不能指定多个处理人")
					else
						# 验证next_user是否合法，调用getHandlersManager.getHandlers(:instance_id,当前trace对应的step_id),判断next_user是否在其返回的结果中
						next_user_ids = getHandlersManager.getHandlers(instance_id, next_step_id)
						if _.difference(next_step_users, next_user_ids).length > 0
							throw new Meteor.Error('error!', "指定的下一步处理人有误")
						else
							# 若合法，执行流转操作
							instance_traces = instance.traces
							i = 0 
							while i < instance_traces.length
								if instance_traces[i]._id is trace_id
									# 更新当前trace记录
									instance_traces[i].is_finished = true
									instance_traces[i].finish_date = new Date
									instance_traces[i].judge = judge
									h = 0
									while h < instance_traces[i].approves.length
										if instance_traces[i].approves[h]._id is approve_id
											# 更新当前trace.approve记录
											instance_traces[i].approves[h].is_finished = true
											instance_traces[i].approves[h].handler = current_user
											instance_traces[i].approves[h].handler_name = current_user_info.name
											instance_traces[i].approves[h].finish_date = new Date
											instance_traces[i].approves[h].handler_organization = space_user_org_info["organization"]
											instance_traces[i].approves[h].handler_organization_name = space_user_org_info["organization_name"]
											instance_traces[i].approves[h].handler_organization_fullname = space_user_org_info["organization_fullname"]
										h++
								i++

							# 插入下一步trace记录
							newTrace = new Object
							newTrace._id = new Mongo.ObjectID()._str
							newTrace.instance = instance_id
							newTrace.previous_trace_ids = [trace_id]
							newTrace.is_finished = false
							newTrace.step = next_step_id
							newTrace.start_date = new Date
							newTrace.approves = new Array
							_.each next_step_users, (next_step_user_id)->
								# 插入下一步trace.approve记录
								newApprove = new Object
								newApprove._id = new Mongo.ObjectID()._str
								newApprove.instance = instance_id
								newApprove.trace = newTrace._id
								newApprove.is_finished = false
								newApprove.user = next_step_user_id

								handler_info = db.users.findOne(next_step_user_id)
								newApprove.user_name = handler_info.name
								newApprove.handler = next_step_user_id
								newApprove.handler_name = handler_info.name

								next_step_space_user = db.space_users.findOne({space: space_id, user: next_step_user_id})
								# 获取next_step_user所在的部门信息
								next_step_user_org_info = uuflowManager.getSpaceUserOrgInfo(next_step_space_user)
								newApprove.handler_organization = next_step_user_org_info["organization"]
								newApprove.handler_organization_name = next_step_user_org_info["organization_name"]
								newApprove.handler_organization_fullname = next_step_user_org_info["organization_fullname"]
								newApprove.start_date = new Date
								newApprove.is_read = false
								newApprove.is_error = false
								newApprove.values = new Object
								newTrace.approves.push(newApprove)

							# 更新instance记录
							setObj.final_decision = judge
							setObj.modified = new Date
							setObj.modified_by = current_user
							setObj.values = uuflowManager.getUpdatedValues(uuflowManager.getInstance(instance_id))
							instance.values = setObj.values
							setObj.name = uuflowManager.getInstanceName(instance)

							instance_trace = _.find(instance_traces, (trace)->
								return trace._id is trace_id
							)
							trace_approve = _.find(instance_trace.approves, (approve)->
								return approve._id is approve_id
							)
							outbox_users = instance.outbox_users
							outbox_users.unshift(trace_approve.user)
							outbox_users.unshift(trace_approve.handler)
							setObj.outbox_users = _.uniq(outbox_users)
							setObj.inbox_users = next_step_users
							instance_traces.push(newTrace)
							setObj.traces = instance_traces
		else if judge is "rejected"
			if not description
				throw new Meteor.Error('error!', "请填写驳回理由")
			else
				# 验证next_steps.step是否合法,判断next_steps.step是否在其中
				nextSteps = uuflowManager.getNextSteps(instance, flow, step, "rejected")
				# 判断next_steps.step是否在nextSteps中,若不在则不合法
				_.each next_steps, (approve_next_step)->
					if not nextSteps.includes(approve_next_step["step"])
						throw new Meteor.Error('error!', "指定的下一步有误")
				# 若合法,执行流转
				next_step_id = next_steps[0]["step"]
				next_step = uuflowManager.getStep(instance, flow, next_step_id)
				next_step_type = next_step["step_type"]
				# 判断next_step是否为结束结点
				if next_step_type is "end"
					# 若是结束结点
					instance_traces = instance.traces
					i = 0 
					while i < instance_traces.length
						if instance_traces[i]._id is trace_id
							# 更新当前trace记录
							instance_traces[i].is_finished = true
							instance_traces[i].finish_date = new Date
							instance_traces[i].judge = judge
							h = 0
							while h < instance_traces[i].approves.length
								if instance_traces[i].approves[h]._id is approve_id
									# 更新当前trace.approve记录
									instance_traces[i].approves[h].is_finished = true
									instance_traces[i].approves[h].handler = current_user
									instance_traces[i].approves[h].handler_name = current_user_info.name
									instance_traces[i].approves[h].finish_date = new Date
									instance_traces[i].approves[h].handler_organization = space_user_org_info["organization"]
									instance_traces[i].approves[h].handler_organization_name = space_user_org_info["organization_name"]
									instance_traces[i].approves[h].handler_organization_fullname = space_user_org_info["organization_fullname"]
								h++
						i++

					# 插入下一步trace记录
					newTrace = new Object
					newTrace._id = new Mongo.ObjectID()._str
					newTrace.instance = instance_id
					newTrace.previous_trace_ids = [trace_id]
					newTrace.is_finished = true
					newTrace.step = next_step_id
					newTrace.start_date = new Date
					newTrace.finish_date = new Date
					newTrace.due_date = if next_step.timeout_hours then (new Date+(60*60*next_step.timeout_hours))

					# 更新instance记录
					setObj.state = "completed"
					setObj.final_decision = judge
					setObj.modified = new Date
					setObj.modified_by = current_user
					setObj.values = uuflowManager.getUpdatedValues(uuflowManager.getInstance(instance_id))
					instance.values = setObj.values
					setObj.name = uuflowManager.getInstanceName(instance)

					instance_trace = _.find(instance_traces, (trace)->
						return trace._id is trace_id
					)
					trace_approve = _.find(instance_trace.approves, (approve)->
						return approve._id is approve_id
					)
					outbox_users = instance.outbox_users
					outbox_users.unshift(trace_approve.handler)
					outbox_users.unshift(trace_approve.user)
					setObj.outbox_users = _.uniq(outbox_users)
					instance_traces.push(newTrace)
					setObj.traces = instance_traces
					setObj.inbox_users=[]
				else
					# 若不是结束结点
					# 先判断nextsteps.step.users是否为空
					next_step_users = next_steps[0]["users"]
					if next_step_users is null or next_step_users.length is 0
						throw new Meteor.Error('error!', "未指定下一步处理人")
					else
						if next_step_users.length > 1 and next_step["step_type"] isnt "counterSign"
							throw new Meteor.Error('error!', "不能指定多个处理人")
						else
							# 验证next_user是否合法，调用getHandlersManager.getHandlers(:instance_id,当前trace对应的step_id),判断next_user是否在其返回的结果中
							next_user_ids = getHandlersManager.getHandlers(instance_id, next_step_id)
							if _.difference(next_step_users, next_user_ids).length > 0
								throw new Meteor.Error('error!', "指定的下一步处理人有误")
							else
								# 若合法，执行流转操作
								instance_traces = instance.traces
								i = 0 
								while i < instance_traces.length
									if instance_traces[i]._id is trace_id
										# 更新当前trace记录
										instance_traces[i].is_finished = true
										instance_traces[i].finish_date = new Date
										instance_traces[i].judge = judge
										h = 0
										while h < instance_traces[i].approves.length
											if instance_traces[i].approves[h]._id is approve_id
												# 更新当前trace.approve记录
												instance_traces[i].approves[h].is_finished = true
												instance_traces[i].approves[h].handler = current_user
												instance_traces[i].approves[h].handler_name = current_user_info.name
												instance_traces[i].approves[h].finish_date = new Date
												instance_traces[i].approves[h].handler_organization = space_user_org_info["organization"]
												instance_traces[i].approves[h].handler_organization_name = space_user_org_info["organization_name"]
												instance_traces[i].approves[h].handler_organization_fullname = space_user_org_info["organization_fullname"]
											h++
									i++

								# 插入下一步trace记录
								newTrace = new Object
								newTrace._id = new Mongo.ObjectID()._str
								newTrace.instance = instance_id
								newTrace.previous_trace_ids = [trace_id]
								newTrace.is_finished = false
								newTrace.step = next_step_id
								newTrace.start_date = new Date
								newTrace.approves = new Array
								_.each next_step_users, (next_step_user_id)->
									# 插入下一步trace.approve记录
									newApprove = new Object
									newApprove._id = new Mongo.ObjectID()._str
									newApprove.instance = instance_id
									newApprove.trace = newTrace._id
									newApprove.is_finished = false
									newApprove.user = next_step_user_id

									handler_info = db.users.findOne(next_step_user_id)
									newApprove.user_name = handler_info.name
									newApprove.handler = next_step_user_id
									newApprove.handler_name = handler_info.name

									next_step_space_user = db.space_users.findOne({space: space_id, user: next_step_user_id})
									# 获取next_step_user所在的部门信息
									next_step_user_org_info = uuflowManager.getSpaceUserOrgInfo(next_step_space_user)
									newApprove.handler_organization = next_step_user_org_info["organization"]
									newApprove.handler_organization_name = next_step_user_org_info["organization_name"]
									newApprove.handler_organization_fullname = next_step_user_org_info["organization_fullname"]
									newApprove.start_date = new Date
									newApprove.is_read = false
									newApprove.is_error = false
									newApprove.values = new Object
									newTrace.approves.push(newApprove)

								# 更新instance记录
								setObj.final_decision = judge
								setObj.modified = new Date
								setObj.modified_by = current_user
								setObj.values = uuflowManager.getUpdatedValues(uuflowManager.getInstance(instance_id))
								instance.values = setObj.values
								setObj.name = uuflowManager.getInstanceName(instance)

								instance_trace = _.find(instance_traces, (trace)->
									return trace._id is trace_id
								)
								trace_approve = _.find(instance_trace.approves, (approve)->
									return approve._id is approve_id
								)
								outbox_users = instance.outbox_users
								outbox_users.unshift(trace_approve.user)
								outbox_users.unshift(trace_approve.handler)
								setObj.outbox_users = _.uniq(outbox_users)
								setObj.inbox_users = next_step_users
								instance_traces.push(newTrace)
								setObj.traces = instance_traces

	return setObj

uuflowManager.engine_step_type_is_counterSign = (instance_id, trace_id, approve_id, next_steps, space_user_org_info, judge, instance, flow, step, current_user, current_user_info) ->
	setObj = new Object
	space_id = instance.space
	# 验证approve的judge是否为空
	if not judge
		throw new Meteor.Error('error!', "请选择核准或驳回。")
	else
		# 验证next_steps.step是否合法,判断next_steps.step是否在其中
		nextSteps = uuflowManager.getNextSteps(instance, flow, step, "approved")
		# 判断next_steps.step是否在nextSteps中,若不在则不合法
		_.each next_steps, (approve_next_step)->
			if not nextSteps.includes(approve_next_step["step"])
				throw new Meteor.Error('error!', "指定的下一步有误")

		# 若合法,执行流转
		next_step_id = next_steps[0]["step"]
		next_step = uuflowManager.getStep(instance, flow, next_step_id)
		next_step_type = next_step["step_type"]

		instance_traces = instance.traces
		isAllApproveFinished = true
		i = 0 
		while i < instance_traces.length
			if instance_traces[i]._id is trace_id
				h = 0
				while h < instance_traces[i].approves.length
					if instance_traces[i].approves[h]._id is approve_id
						# 更新当前trace.approve记录
						instance_traces[i].approves[h].is_finished = true
						instance_traces[i].approves[h].handler = current_user
						instance_traces[i].approves[h].handler_name = current_user_info.name
						instance_traces[i].approves[h].finish_date = new Date
						instance_traces[i].approves[h].handler_organization = space_user_org_info["organization"]
						instance_traces[i].approves[h].handler_organization_name = space_user_org_info["organization_name"]
						instance_traces[i].approves[h].handler_organization_fullname = space_user_org_info["organization_fullname"]

					if instance_traces[i].approves[h].is_finished is false and instance_traces[i].approves[h].type isnt 'cc'
						isAllApproveFinished = false

					h++
			i++

		if isAllApproveFinished is true
			i = 0 
			while i < instance_traces.length
				if instance_traces[i]._id is trace_id
					# 更新当前trace记录
					instance_traces[i].is_finished = true
					instance_traces[i].finish_date = new Date
					instance_traces[i].judge = "submitted"
				i++

			# 判断next_step是否为结束结点
			if next_step_type is "end"
				# 插入下一步trace记录
				newTrace = new Object
				newTrace._id = new Mongo.ObjectID()._str
				newTrace.instance = instance_id
				newTrace.previous_trace_ids = [trace_id]
				newTrace.is_finished = true
				newTrace.step = next_step_id
				newTrace.start_date = new Date
				newTrace.finish_date = new Date
				newTrace.due_date = if next_step.timeout_hours then (new Date+(60*60*next_step.timeout_hours))
				# 更新instance记录
				setObj.state = "completed"
				setObj.modified = new Date
				setObj.modified_by = current_user

				instance_trace = _.find(instance_traces, (trace)->
					return trace._id is trace_id
				)

				outbox_users = instance.outbox_users
				_.each instance_trace.approves, (appro)->
					outbox_users.push appro.user
					outbox_users.push appro.handler

				setObj.outbox_users = _.uniq(outbox_users)
				setObj.inbox_users = new Array
				instance_traces.push(newTrace)
				setObj.traces = instance_traces
			else
				# 若不是结束结点
				# 先判断nextsteps.step.users是否为空
				next_step_users = next_steps[0]["users"]
				if next_step_users is null or next_step_users.length is 0
					throw new Meteor.Error('error!', "未指定下一步处理人")
				else
					if next_step_users.length > 1 and next_step["step_type"] isnt "counterSign"
						throw new Meteor.Error('error!', "不能指定多个处理人")
					else
						# 验证next_user是否合法，调用getHandlersManager.getHandlers(:instance_id,当前trace对应的step_id),判断next_user是否在其返回的结果中
						next_user_ids = getHandlersManager.getHandlers(instance_id, next_step_id)
						if _.difference(next_step_users, next_user_ids).length > 0
							throw new Meteor.Error('error!', "指定的下一步处理人有误")
						else
							# 插入下一步trace记录
							newTrace = new Object
							newTrace._id = new Mongo.ObjectID()._str
							newTrace.instance = instance_id
							newTrace.previous_trace_ids = [trace_id]
							newTrace.is_finished = false
							newTrace.step = next_step_id
							newTrace.start_date = new Date
							newTrace.approves = new Array
							_.each next_step_users, (next_step_user_id)->
								# 插入下一步trace.approve记录
								newApprove = new Object
								newApprove._id = new Mongo.ObjectID()._str
								newApprove.instance = instance_id
								newApprove.trace = newTrace._id
								newApprove.is_finished = false
								newApprove.user = next_step_user_id

								handler_info = db.users.findOne(next_step_user_id)
								newApprove.user_name = handler_info.name
								newApprove.handler = next_step_user_id
								newApprove.handler_name = handler_info.name

								next_step_space_user = db.space_users.findOne({space: space_id, user: next_step_user_id})
								# 获取next_step_user所在的部门信息
								next_step_user_org_info = uuflowManager.getSpaceUserOrgInfo(next_step_space_user)
								newApprove.handler_organization = next_step_user_org_info["organization"]
								newApprove.handler_organization_name = next_step_user_org_info["organization_name"]
								newApprove.handler_organization_fullname = next_step_user_org_info["organization_fullname"]
								newApprove.start_date = new Date
								newApprove.is_read = false
								newApprove.is_error = false
								newApprove.values = new Object
								newTrace.approves.push(newApprove)

							# 更新instance记录
							setObj.modified = new Date
							setObj.modified_by = current_user
							
							instance_trace = _.find(instance_traces, (trace)->
								return trace._id is trace_id
							)
							outbox_users = instance.outbox_users
							_.each instance_trace.approves, (appro)->
								outbox_users.push appro.user
								outbox_users.push appro.handler

							setObj.outbox_users = _.uniq(outbox_users)
							setObj.inbox_users = next_step_users
							instance_traces.push(newTrace)
							setObj.traces = instance_traces
		else
			# 当前trace未结束
			instance_trace = _.find(instance_traces, (trace)->
				return trace._id is trace_id
			)
			trace_approve = _.find(instance_trace.approves, (approve)->
				return approve._id is approve_id
			)
			outbox_users = instance.outbox_users
			outbox_users.unshift(trace_approve.handler)
			outbox_users.unshift(trace_approve.user)
			setObj.outbox_users = _.uniq(outbox_users)
			for_remove = new Array
			for_remove.push trace_approve.handler
			for_remove.push trace_approve.user
			for_remove = _.uniq(for_remove)

			setObj.inbox_users = _.difference(instance.inbox_users, for_remove)
			setObj.modified = new Date
			setObj.modified_by = current_user

			setObj.traces = instance_traces

	return setObj

# 生成HTML格式只读表单和签核历程, 由于此方法生成的html数据会作为邮件内容发送，为了再邮件中样式显示正常，
# 请不要写单独的css，所有样式请写在html标签的style属性中。
uuflowManager.ins_html = (ins, lang="zh-CN")->
	return ""

uuflowManager.create_instance = (instance_from_client, user_info)->
	space_id = instance_from_client["space"]
	flow_id = instance_from_client["flow"]
	instance_flow_version = instance_from_client["flow_version"]
	user_id = user_info._id
	# 获取前台所传的trace
	trace_from_client = null
	# 获取前台所传的approve
	approve_from_client = null
	if instance_from_client["traces"] and instance_from_client["traces"][0]
		trace_from_client = instance_from_client["traces"][0]
		if trace_from_client["approves"] and trace_from_client["approves"][0]
			approve_from_client = instance_from_client["traces"][0]["approves"][0]

	# 获取一个space
	space = uuflowManager.getSpace(space_id)
	# 获取一个flow
	flow = uuflowManager.getFlow(flow_id)
	# 获取一个space下的一个user
	space_user = uuflowManager.getSpaceUser(space_id, user_id)
	# 获取space_user所在的部门信息
	space_user_org_info = uuflowManager.getSpaceUserOrgInfo(space_user)
	# 判断一个flow是否为启用状态
	uuflowManager.isFlowEnabled(flow)
	# 判断一个flow和space_id是否匹配 
	uuflowManager.isFlowSpaceMatched(flow, space_id)

	permissions = permissionManager.getFlowPermissions(flow_id, user_id)

	if not permissions.includes("add")
		throw new Meteor.Error('error!', "当前用户没有此流程的新建权限")

	space_user = db.space_users.findOne(
		space: space_id
		user: user_id
	)
	space_user_org_info = db.organizations.findOne(space_user.organization)
	now = new Date
	ins_obj = {}
	ins_obj._id = db.instances._makeNewID()
	ins_obj.space = space_id
	ins_obj.flow = flow_id
	ins_obj.flow_version = flow.current._id
	ins_obj.form = flow.form
	ins_obj.form_version = flow.current.form_version
	ins_obj.name = flow.name
	ins_obj.submitter = user_id
	ins_obj.submitter_name = user_info.name
	ins_obj.applicant = user_id
	ins_obj.applicant_name = user_info.name
	ins_obj.applicant_organization = space_user.organization
	ins_obj.applicant_organization_name = space_user_org_info.name
	ins_obj.applicant_organization_fullname = space_user_org_info.fullname
	ins_obj.state = 'draft'
	ins_obj.code = ''
	ins_obj.is_archived = false
	ins_obj.is_deleted = false
	ins_obj.created = now
	ins_obj.created_by = user_id
	ins_obj.modified = now
	ins_obj.modified_by = user_id
	ins_obj.values = new Object
	# 新建Trace
	trace_obj = {}
	trace_obj._id = Meteor.uuid()
	trace_obj.instance = ins_obj._id
	trace_obj.is_finished = false
	# 当前最新版flow中开始节点的step_id
	step_id = undefined
	flow.current.steps.forEach (step) ->
		if step.step_type == 'start'
			step_id = step._id

	trace_obj.step = step_id
	trace_obj.start_date = now
	# 新建Approve
	appr_obj = {}
	appr_obj._id = Meteor.uuid()
	appr_obj.instance = ins_obj._id
	appr_obj.trace = trace_obj._id
	appr_obj.is_finished = false
	appr_obj.user = user_id
	appr_obj.user_name = user_info.name
	appr_obj.handler = user_id
	appr_obj.handler_name = user_info.name
	appr_obj.handler_organization = space_user.organization
	appr_obj.handler_organization_name = space_user_org_info.name
	appr_obj.handler_organization_fullname = space_user_org_info.fullname
	appr_obj.type = 'draft'
	appr_obj.start_date = now
	appr_obj.read_date = now
	appr_obj.is_read = true
	appr_obj.is_error = false
	appr_obj.description = ''
	appr_obj.values = if approve_from_client and approve_from_client["values"] then approve_from_client["values"] else new Object

	trace_obj.approves = [ appr_obj ]
	ins_obj.traces = [ trace_obj ]

	new_ins_id = db.instances.insert(ins_obj)

	return new_ins_id

uuflowManager.submit_instance = (instance_from_client, user_info)->

	current_user = user_info._id
	lang = "en"
	if user_info.locale is 'zh-cn'
		lang = 'zh-CN'

	instance_id = instance_from_client["id"]
	trace_id = instance_from_client["traces"][0]["id"]
	approve_id = instance_from_client["traces"][0]["approves"][0]["id"]
	values = instance_from_client["traces"][0]["approves"][0]["values"]
	if not values
		values = new Object
	#　验证表单上的applicant已填写
	if not instance_from_client["applicant"]
		throw new Meteor.Error('error!', "请选择申请人")

	applicant_id = instance_from_client["applicant"]
	submitter_id = instance_from_client["submitter"]
	next_steps = instance_from_client["traces"][0]["approves"][0]["next_steps"]
	attachments = instance_from_client["traces"][0]["approves"][0]["attachments"]
	description = instance_from_client["traces"][0]["approves"][0]["description"]
	# 获取一个instance
	instance = uuflowManager.getInstance(instance_id)
	space_id = instance.space
	flow_id = instance.flow
	# 获取一个space
	space = uuflowManager.getSpace(space_id)
	# 校验申请人user_accepted = true
	checkApplicant = uuflowManager.getSpaceUser(space_id, applicant_id)
	# 获取一个flow
	flow = uuflowManager.getFlow(flow_id)
	# 确定instance的name
	instance_name = instance_from_client["name"]
	# 判断一个instance是否为拟稿状态
	uuflowManager.isInstanceDraft(instance, lang)
	# 获取一个space下的一个user
	space_user = uuflowManager.getSpaceUser(space_id, current_user)
	# 获取space_user所在的部门信息
	space_user_org_info = uuflowManager.getSpaceUserOrgInfo(space_user)
	# 判断一个用户是否是一个instance的提交者
	uuflowManager.isInstanceSubmitter(instance, current_user)
	# 判断一个flow是否为启用状态
	uuflowManager.isFlowEnabled(flow)
	# 验证该user_id或其所在的组有提交此申请单的权限
	permissions = permissionManager.getFlowPermissions(flow_id, current_user)
	if not permissions.includes("add")
		throw new Meteor.Error('error!', "该申请人没有提交此申请单的权限。")

	trace = instance_from_client["traces"][0]
	# 获取一个step
	step = uuflowManager.getStep(instance, flow, trace["step"])
	approve = trace["approves"][0]
	# 先执行暂存的操作
	# ================begin================
	form = db.forms.findOne(instance.form)
	# 获取Flow当前版本开始节点step_id
	steps = flow.current.steps
	step_id = null
	_.each(steps, (step)->
		if step.step_type is "start"
			step_id = step._id
	)

	instance_traces = instance.traces
	instance_traces[0]["approves"][0].description = description
	setObj = new Object
	flow_has_upgrade = false
	# 判断:applicant和原instance的applicant是否相等
	if applicant_id is instance.applicant
		# applicant和原instance的applicant相等
		# 判断流程是否已升级，instance["flow_version"] == flow["current"]["id"]表示流程未升级
		if instance.flow_version is flow.current._id
			instance_traces[0]["approves"][0].values = values
			instance_traces[0]["approves"][0].judge = "submitted"
			# 判断next_steps是否为空,不为空则写入到当前approve的next_steps中
			if next_steps
				instance_traces[0]["approves"][0].next_steps = next_steps

			setObj.modified = new Date
			setObj.modified_by = current_user
		else
			# 流程已升级
			flow_has_upgrade = true
			# 更新instance记录
			setObj.flow_version = flow.current._id
			setObj.form_version = flow.current.form_version
			setObj.modified = new Date
			setObj.modified_by = current_user
			# 清空原来的值， 存入当前最新版flow中开始节点的step_id
			instance_traces[0].step = step_id
			instance_traces[0]["approves"][0].values = values
			instance_traces[0]["approves"][0].judge = "submitted"

	else
		# applicant和原instance的applicant不相等
		user = uuflowManager.getUser(applicant_id)
		applicant = uuflowManager.getSpaceUser(space_id, applicant_id)
		# 获取applicant所在的部门信息
		applicant_org_info = uuflowManager.getSpaceUserOrgInfo(applicant)
		# 修改instance的applicant,applicant_name，同时修改开始结点的approve的user为:applicant,user_name
		setObj.applicant = applicant_id
		setObj.applicant_name = user.name
		setObj.applicant_organization = applicant_org_info["organization"]
		setObj.applicant_organization_name = applicant_org_info["organization_name"]
		setObj.applicant_organization_fullname = applicant_org_info["organization_fullname"]
		instance_traces[0]["approves"][0].user = applicant_id
		instance_traces[0]["approves"][0].user_name = user.name
		instance_traces[0]["approves"][0].judge = "submitted"

		# 判断流程是否已升级，instance["flow_version"] == flow["current"]["id"]表示流程未升级
		if instance.flow_version is flow.current._id
			instance_traces[0]["approves"][0].values = values
			# 判断next_steps是否为空,不为空则写入到当前approve的next_steps中
			if next_steps
				instance_traces[0]["approves"][0].next_steps = next_steps
				setObj.modified = new Date
				setObj.modified_by = current_user
		else
			# 流程已升级
			flow_has_upgrade = true
			# 更新instance记录
			setObj.flow_version = flow.current._id
			setObj.form_version = flow.current.form_version
			setObj.modified = new Date
			setObj.modified_by = current_user
			# 清空原来的值， 存入当前最新版flow中开始节点的step_id
			instance_traces[0].step = step_id
			instance_traces[0]["approves"][0].values = values

	setObj.traces = instance_traces
	db.instances.update({_id: instance_id}, {$set: setObj})
	if flow_has_upgrade
		return { alerts: TAPi18n.__('flow.point_upgraded',{},lang) }
	# ================end================
	instance = db.instances.findOne(instance_id) #使用最新的instance
	traces = instance.traces
	upObj = new Object

	if (not approve["next_steps"]) or (approve["next_steps"].length is 0)
		throw new Meteor.Error('error!', "还未指定下一步和处理人，提交失败")
	else
		# 验证next_steps里面是否只有一个step
		if approve["next_steps"].length > 1
			throw new Meteor.Error('error!', "不能指定多个后续步骤")
		else
			nextSteps = uuflowManager.getNextSteps(instance, flow, step, "")
			_.each(approve["next_steps"], (approve_next_step)->
				if not nextSteps.includes(approve_next_step["step"])
					throw new Meteor.Error('error!', "下一步步骤不合法")
			)
	# 校验下一步处理人user_accepted = true
	_.each(approve["next_steps"][0]["users"], (next_step_user)->
		uuflowManager.getSpaceUser(space_id, next_step_user)
	)
	next_step = uuflowManager.getStep(instance, flow, approve["next_steps"][0]["step"])
	# 判断next_step是否为结束结点
	if next_step.step_type is "end"
		
		# 更新approve
		traces[0]["approves"][0].is_finished = true
		traces[0]["approves"][0].finish_date = new Date
		# 更新trace
		traces[0].is_finished = true
		traces[0].judge = "submitted"
		traces[0].finish_date = new Date
		# 插入下一步trace记录
		newTrace = new Object
		newTrace._id = new Mongo.ObjectID()._str
		newTrace.instance = instance_id
		newTrace.previous_trace_ids = [trace["id"]]
		newTrace.is_finished = true
		newTrace.step = next_step._id
		newTrace.start_date = new Date
		newTrace.finish_date = new Date
		# 更新instance记录
		# 申请单名称按照固定规则生成申请单名称：流程名称＋' '+申请单编号
		upObj.submit_date = new Date
		upObj.state = "completed"
		upObj.values = uuflowManager.getUpdatedValues(uuflowManager.getInstance(instance_id))
		upObj.code = flow.current_no + 1 + ""
		instance.code = upObj.code
		instance.values = upObj.values
		upObj.name = uuflowManager.getInstanceName(instance)
		upObj.modified = new Date
		upObj.modified_by = current_user
		upObj.inbox_users = []
		upObj.outbox_users = [current_user]
		# 调整approves 的values 删除values中在当前步骤中没有编辑权限的字段值
		traces[0]["approves"][0].values = uuflowManager.getApproveValues(traces[0]["approves"][0].values,step.permissions,instance.form,instance.form_version)
		traces.push(newTrace)
		upObj.traces = traces
	else # next_step不为结束节点
		# 取得下一步处理人
		next_step_users = approve["next_steps"][0]["users"]
		# 判断nextsteps.step.users是否为空
		if (not next_step_users) or (next_step_users.length is 0)
			throw new Meteor.Error('error!', "未指定下一步处理人")
		else
			if next_step_users.length > 1 and next_step.step_type isnt "counterSign"
				throw new Meteor.Error('error!', "不能指定多个处理人")
			else
				# 验证下一步处理人next_user是否合法
				checkUsers = getHandlersManager.getHandlers(instance_id, approve["next_steps"][0]["step"])
				if _.difference(next_step_users, checkUsers).length > 0
					throw new Meteor.Error('error!', "指定的下一步处理人有误")
				else
					# 若合法，执行流转操作
					# 更新approve
					traces[0]["approves"][0].is_finished = true
					traces[0]["approves"][0].finish_date = new Date
					# 更新trace
					traces[0].is_finished = true
					traces[0].finish_date = new Date
					traces[0].judge = "submitted"
					# 插入下一步trace记录
					nextTrace = new Object
					nextTrace._id = new Mongo.ObjectID()._str
					nextTrace.instance = instance_id
					nextTrace.previous_trace_ids = [trace["id"]]
					nextTrace.is_finished = false
					nextTrace.step = next_step._id
					nextTrace.start_date = new Date
					if next_step.timeout_hours
						due_time = new Date().getTime() + (1000 * 60 * 60 * next_step.timeout_hours)
						nextTrace.due_date = new Date(due_time)
					nextTrace.approves = new Array
					# 插入下一步trace.approve记录
					_.each(next_step_users, (next_step_user_id)->
						nextApprove = new Object
						nextApprove._id = new Mongo.ObjectID()._str
						nextApprove.instance = instance_id
						nextApprove.trace = nextTrace._id
						nextApprove.is_finished = false
						nextApprove.user = next_step_user_id
						handler_info = uuflowManager.getUser(next_step_user_id)
						nextApprove.user_name = handler_info.name
						nextApprove.handler = next_step_user_id
						nextApprove.handler_name = handler_info.name
						next_step_space_user = uuflowManager.getSpaceUser(space_id, next_step_user_id)
						# 获取next_step_user所在的部门信息
						next_step_user_org_info = uuflowManager.getSpaceUserOrgInfo(next_step_space_user)
						nextApprove.handler_organization = next_step_user_org_info["organization"]
						nextApprove.handler_organization_name = next_step_user_org_info["organization_name"]
						nextApprove.handler_organization_fullname = next_step_user_org_info["organization_fullname"]
						nextApprove.start_date = new Date
						nextApprove.due_date = nextTrace.due_date
						nextApprove.is_read = false
						nextApprove.is_error = false
						nextApprove.values = new Object
						nextTrace.approves.push(nextApprove)
					)
					# 更新instance记录
					upObj.name = instance_name
					upObj.submit_date = new Date
					upObj.state = "pending"
					# 重新查找暂存之后的instance
					upObj.values = uuflowManager.getUpdatedValues(uuflowManager.getInstance(instance_id))
					upObj.inbox_users = next_step_users
					upObj.modified = new Date
					upObj.modified_by = current_user
					# 申请单名称按照固定规则生成申请单名称：流程名称＋' '+申请单编号
					upObj.code = flow.current_no + 1 + ""
					instance.code = upObj.code
					instance.values = upObj.values
					upObj.name = uuflowManager.getInstanceName(instance)
					# 调整approves 的values 删除values中在当前步骤中没有编辑权限的字段值
					traces[0]["approves"][0].values = uuflowManager.getApproveValues(traces[0]["approves"][0].values,step["permissions"],instance.form,instance.form_version)
					traces.push(nextTrace)
					upObj.traces = traces
					upObj.outbox_users = []

	db.instances.update({_id: instance_id}, {$set: upObj})
	db.flows.direct.update({_id: flow._id}, {$set: {current_no: flow.current_no+1}})
	if next_step.step_type isnt "end"
		instance = db.instances.findOne(instance_id)
		#发送短消息给申请人
		pushManager.send_instance_notification("first_submit_applicant",instance,"",user_info)
		# 发送消息给下一步处理人
		pushManager.send_instance_notification("first_submit_inbox",instance,"",user_info)
	return {}

uuflowManager.get_SpaceChangeSet = (formids, is_admin, sync_token)->
	sync_token = new Date(Number(sync_token)*1000)
	changeSet = new Object
	changeSet.sync_token = new Date().getTime()/1000
	changeSet.inserts = { Spaces: [], Users: [], SpaceUsers: [], Organizations: [], Roles: [], Positions: [], Forms: [], Flows: [], Instances: []}
	changeSet.updates = { Spaces: [], Users: [], SpaceUsers: [], Organizations: [], Roles: [], Positions: [], Forms: [], Flows: [], Instances: []}
	changeSet.deletes = { Spaces: [], Users: [], SpaceUsers: [], Organizations: [], Roles: [], Positions: [], Forms: [], Flows: [], Instances: []}

	if formids and formids.trim()
		formids_ary = formids.split(",")
		changeSet.inserts.Instances = db.instances.find({
			form: {$in: formids_ary},
			created: {$gt: sync_token}
		}).fetch()
		changeSet.updates.Instances = db.instances.find({
			form: {$in: formids_ary},
			created: {$lte: sync_token},
			modified: {$gt: sync_token}
		}).fetch()
		changeSet.deletes.Instances = db.deleted_instances.find({
			form: {$in: formids_ary},
			deleted: {$gt: sync_token}
		}, {fields: {_id: 1}}).fetch()

	else if is_admin and is_admin.trim()
		changeSet.inserts.Instances = db.instances.find({
			created: {$gt: sync_token}
		}).fetch()
		changeSet.updates.Instances = db.instances.find({
			created: {$lte: sync_token},
			modified: {$gt: sync_token}
		}).fetch()
		changeSet.deletes.Instances = db.deleted_instances.find({
			deleted: {$gt: sync_token}
		}, {fields: {_id: 1}}).fetch()

	# 查询提交人和申请人steedos_id
	_.each changeSet.inserts.Instances, (ins)->
		submitter = db.users.findOne({_id: ins.submitter}, {fields: {steedos_id: 1}})
		applicant = db.users.findOne({_id: ins.applicant}, {fields: {steedos_id: 1}})
		ins.submitter_steedos_id = submitter.steedos_id if submitter
		ins.applicant_steedos_id = applicant.steedos_id if applicant
	_.each changeSet.updates.Instances, (ins)->
		submitter = db.users.findOne({_id: ins.submitter}, {fields: {steedos_id: 1}})
		applicant = db.users.findOne({_id: ins.applicant}, {fields: {steedos_id: 1}})
		ins.submitter_steedos_id = submitter.steedos_id if submitter
		ins.applicant_steedos_id = applicant.steedos_id if applicant

	return {ChangeSet: changeSet}