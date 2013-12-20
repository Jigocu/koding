class FormGeneratorView extends JView
  constructor:(options,data)->
    super options,data

    @setClass 'form-generator'

    @listController = new KDListViewController
      itemClass     : FormGeneratorItemView

    @listWrapper    = @listController.getView()
    @listWrapper.setClass 'form-builder'

    ###
    Single-Value Input Views
    ###

    @inputTitle = new KDInputView
      name          : 'title'
      placeholder   : 'Field title, e.g. "Student ID"'
      keyup : (event)=>
        @inputKey.setValue @utils.slugify(@inputTitle.getValue()).replace(/-/g,'_')
      validate      :
        rules       :
          required  : yes
        messages    :
          required  : "A title is required!"

    @inputKey = new KDInputView
      name          : 'key'
      placeholder   : 'Field key, e.g. "student_id"'

    @inputDefault = new KDInputView
      name          : 'defaultValue'
      placeholder   : 'Default value'

    @inputDefaultTextarea = new KDInputView
      name          : 'defaultValueTextarea'
      type          : 'textarea'
      cssClass      : 'add-textarea'

    @inputDefaultSelect = new KDSelectBox
      name          : 'defaultValueSelect'

    @inputDefaultRadio = new KDInputRadioGroup
      radios        : []
      name          : 'defaultValueRadio'

    @inputDefaultSwitch = new KDOnOffSwitch
      defaultValue  : @getData().defaultValue or no

    @inputType      = new KDSelectBox
      name          : 'type'
      cssClass      : 'type-select'
      selectOptions : [
        {title:'Text Field'         ,value:'text'},
        {title:'Select Box'         ,value:'select'},
        {title:'On-Off Switch'      ,value:'checkbox'},
        {title:'Textarea'           ,value:'textarea'},
        {title:'Radio Button Field' ,value:'radio'}
      ]
      change        : =>
        switch @inputType.getValue()
          when 'select'   then @decorateInputs ['Select']
          when 'checkbox' then @decorateInputs ['Switch']
          when 'textarea' then @decorateInputs ['Textarea']
          when 'radio'    then @decorateInputs ['Radio']
          else @decorateInputs()

    ###
    Multi-item Input Views (radio, select)
    ###

    @inputFieldsSelect = new FormGeneratorMultipleInputView
      cssClass  : 'select-fields'
      type      : 'select'
      title     : 'Dropdown'

    @inputFieldsRadio = new FormGeneratorMultipleInputView
      cssClass  : 'radio-fields'
      type      : 'radio'
      title     : 'Radio'

    @inputFieldsSelect.on 'InputChanged', ({type,value})=>
      @inputDefaultSelect.removeSelectOptions()
      @inputDefaultSelect.setSelectOptions value
      @inputDefaultSelect.setValue value[0]

    @inputFieldsRadio.on 'InputChanged', ({type,value})=>
      @inputDefaultRadio.$().empty()
      for item,i in value
        id = @utils.getRandomNumber()
        @inputDefaultRadio.$().append \
          """
            <div class='kd-radio-holder'>
              <input id="#{id}" class='no-kdinput' type='radio' name='add-radio' value='#{item.value}' />
              <label for="#{id}">#{item.title}</label>
            </div>
          """
        @inputDefaultRadio.setDefaultValue value[0]

    ###
    Buttons
    ###

    @addButton      = new CustomLinkView
      tagName       : 'span'
      title         : 'Add field'
      style         : 'clean-gray'
      cssClass      : 'add-button'
      click         : =>
        @addFieldToList()

    @saveButton = new KDButtonView
      title     : 'Save fields'
      cssClass  : 'clean-gray save-button'
      loader    :
        diameter: 12
        color   : '#444'
      callback  :=>
        @saveToMembershipPolicy()

    @inputDefaultSelect.hide()
    @inputDefaultRadio.hide()
    @inputDefaultSwitch.hide()
    @inputDefaultTextarea.hide()

    @inputFieldsSelect.hide()
    @inputFieldsRadio.hide()

    @listController.listView.on 'RemoveButtonClicked', (instance)=>
      @listController.removeItem instance,{}

    policy = @getData()
    if policy.fields
      for field in policy.fields
        @listController.addItem
          title        : field.title or ''
          defaultValue : field.defaultValue or ''
          key          : field.key
          type         : field.type or 'text'
          options      : field.options

  saveToMembershipPolicy:->
    newFields = []
    for item in @listController.listView.items

      {type,title,key,defaultValue,options} = item.getData()

      newFields.push
        key           : Encoder.XSSEncode key
        type          : type
        title         : Encoder.XSSEncode title
        defaultValue  :
          if 'string' is typeof defaultValue
            Encoder.XSSEncode defaultValue
          else defaultValue
        options       : options if options


    @getDelegate().emit 'MembershipPolicyChanged', {fields : newFields}
    @getDelegate().once 'MembershipPolicyChangeSaved', =>
      @saveButton.hideLoader()

  addFieldToList:->
    key = @inputKey.getValue()
    newItem = key isnt ''
    for item in @listController.listView.items
      if item.getData().key is key
        newItem = false

    if newItem
      @listController.addItem
        title       : Encoder.XSSEncode @inputTitle.getValue()
        key         : Encoder.XSSEncode @inputKey.getValue()
        defaultValue: switch @inputType.getValue()
          when 'text'     then Encoder.XSSEncode @inputDefault.getValue()
          when 'select'   then @inputDefaultSelect.getValue()
          when 'checkbox' then @inputDefaultSwitch.getValue()
          when 'radio'    then @inputDefaultRadio.getValue()
          when 'textarea' then @inputDefaultTextarea.getValue()
          else Encoder.XSSEncode @inputDefault.getValue()
        type        : @inputType.getValue()
        options     : switch @inputType.getValue()
          when 'select'
            @inputFieldsSelect.getValue()
          when 'radio'
            @inputFieldsRadio.getValue()

      @inputTitle.setValue ''
      @inputKey.setValue ''
      @inputDefault.setValue ''

      @inputFieldsSelect.listController.removeAllItems()
      @inputDefaultSelect.removeSelectOptions()
      @inputDefaultSelect.setValue null

    else
      new KDNotificationView
        title : if key is '' then 'Please enter a key' else 'Duplicate key'

  decorateInputs:(show=[''])->
    for inputSection in ['Fields','Default']
      for input in ['Text','Textarea','Select','Radio','Switch','']
        @['input'+inputSection+input]?[if input in show then "show" else "hide"]()

  pistachio:->
    """
    <div class="wrapper">
      <div class="add-header">
        <div class="add-type">Field type</div>
        <div class="add-title">Title</div>
        <div class="add-key">Key</div>
        <div class="add-default">Default</div>
      </div>

      {{> @listWrapper}}

      <div class="add-inputs">
        <div class='add-input'>{{> @inputType}}</div>
        <div class='add-input'>{{> @inputTitle}}</div>
        <div class='add-input'>{{> @inputKey}}</div>
        <div class='add-input'>
          {{> @inputDefault}}
          {{> @inputDefaultSelect}}
          {{> @inputDefaultSwitch}}
          {{> @inputDefaultRadio}}
          {{> @inputDefaultTextarea}}
          </div>
        <div class='add-input button'>{{> @addButton}}</div>
        <div class='add-input select'>{{> @inputFieldsSelect}}{{> @inputFieldsRadio}}</div>
      </div>
    </div>
    {{> @saveButton}}
    """

class FormGeneratorMultipleInputView extends JView
  constructor:(options,data)->
    super options,data

    {type,title} = @getOptions()

    @listController = new KDListViewController
      itemClass     : FormGeneratorMultipleInputItemView
      noItemView    : new KDListItemView
        cssClass    : 'default-item'
        partial     : "Please add #{title} options"

    @listWrapper      = @listController.getView()
    @listWrapper.setClass "form-builder-#{type}"

    @inputTitle = new KDInputView
      cssClass  : 'title'

    @addButton  = new CustomLinkView
      cssClass  : 'add-button'
      tagName   : 'span'
      title     : 'Add option'
      click     : =>
        @listController.addItem
          title : Encoder.XSSEncode @inputTitle.getValue()
          value : @utils.slugify(@inputTitle.getValue()).replace(/-/g,'_')

        @emit 'InputChanged', {
          type
          value:@getValue()
        }

        @inputTitle.setValue ''

    @listController.listView.on 'RemoveButtonClicked', (instance)=>
      @listController.removeItem instance,{}
      @emit 'InputChanged', {
        type
        value:@getValue()
      }

  getValue:->
    data = []
    for item in @listController.listView.items
      data.push
        title : item.getData().title
        value : @utils.slugify(item.getData().title).replace(/-/g,'_')
    data

  pistachio:->
    """
    <h3>#{@getOptions().title} items</h3>
    {{> @listWrapper}}
    {{> @inputTitle}}
    {{> @addButton}}
    """


class FormGeneratorMultipleInputItemView extends KDListItemView
  constructor:(options,data)->
    super options,data

    @optionTitle  = new KDView
      cssClass    : 'title'
      partial     : @getData().title+" <span class='value'>(#{@getData().value})</span>"

    @removeButton = new CustomLinkView
      tagName     : 'span'
      cssClass    : 'clean-gray remove-button'
      title       : 'Remove'
      click       :=>
        @getDelegate().emit 'RemoveButtonClicked', @

  viewAppended:->
    super
    @setTemplate @pistachio()
    @template.update()

  pistachio:->
    """
    {{> @optionTitle}}
    {{> @removeButton}}
    """


class FormGeneratorItemView extends KDListItemView
  constructor:(options,data)->
    super options,data

    {type,title,key,defaultValue,options} = @getData()

    @type = new KDView
      cssClass    : 'type'
      partial     : switch type
        when 'text'     then 'Text Field'
        when 'select'   then 'Select Box'
        when 'checkbox' then 'On-Off Switch'
        when 'radio'    then 'Radio Buttons'
        when 'textarea' then 'Textarea'
        else 'Other'
      tooltip     :
        title     : type
        placement : 'top'
        direction : 'center'

    @title = new KDView
      cssClass    : 'title'
      partial     : title
      tooltip     :
        title     : title
        placement : 'top'
        direction : 'center'

    @key = new KDView
      cssClass    : 'key'
      partial     : key
      tooltip     :
        title     : key
        placement : 'top'
        direction : 'center'

    switch type
      when 'text', 'textarea'
        @defaultValue = new KDView
          cssClass    : "default #{type}"
          partial     : defaultValue or '<span>none</span>'
          tooltip     :
            title     : defaultValue
            placement : 'top'
            direction : 'center'

      when 'select'
        @defaultValue   = new KDSelectBox
          cssClass      : 'default'
          selectOptions : options or []
          defaultValue  : defaultValue

      when 'radio'
        @defaultValue   = new KDInputRadioGroup
          radios        : options
          name          : 'radios_'+@utils.getRandomNumber()
          cssClass      : 'default'
        @defaultValue.setDefaultValue defaultValue

      when 'checkbox'
        @defaultValue   = new KDOnOffSwitch
          size         : "tiny"
          cssClass      : 'default'
          defaultValue  : defaultValue

    @removeButton = new CustomLinkView
      tagName     : 'span'
      cssClass    : 'clean-gray remove-button'
      title       : 'Remove'
      click       :=>
        @getDelegate().emit 'RemoveButtonClicked', @

  viewAppended:->
    @setClass "form-item"

    @setTemplate @pistachio()
    @template.update()

  pistachio:->
    """
    {{> @type}}
    {{> @title}}
    {{> @key}}
    <div class="default">{{> @defaultValue}}</div>
    {{> @removeButton}}
    """


class GroupsFormGeneratorView extends FormGeneratorView
