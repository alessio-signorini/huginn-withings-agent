module Agents
  class WithingsAgent < Agent
    include FormConfigurable

    cannot_be_scheduled!
    cannot_create_events!
    can_dry_run!

    description <<-MD
      Adds Activities from Events to your Withings Account

      This agent will create new activities in your Withings account from
      events. This is useful if you own multiple devices (e.g., a Fitbit and
      a Withings) and want to consolidate your calories consumption into one.

      Withings has an OAUTHv2 API but it only allows to read activities. This
      agent simulates Withings' Website to add activities using their private
      one. This is why it requires username and password. The password is not
      stored in plain text.

      You can retrieve your `user_id` from the website. Login with your
      credentials then look at the URL. The `user_id` is the number at the
      beginning.

      ## Example Event
      The agent expects an event with the following fields
      <pre>
        {
          'activity_name'   => 'Walking',               # o/w defaults to `other`
          'timezone'        => 'America/Los_Angeles',   # o/w uses `options`
          'start_time'      => 1578401100,              # epoch
          'end_time'        => 1578404700,              # epoch
          'calories'        => 500,                     # kcal
          'distance'        => 1000,                    # in meters
          'intensity'       => 40,                      # defaults to 50
        }
      </pre>

      If `end_time` is not available one can specify `duration` in seconds,
        similarly, if `subcategory` is known it can be specified instead of
        `activity_name`.

      Valid `activity_name` are walking (1), running (2), hiking (3),
        bicycling (6), swimming (7), tennis (12), weights (16), class (17),
        elliptical (18), basketball (20), soccer (21), volleyball (24) and
        yoga (28).
    MD

    form_configurable :username
    form_configurable :password
    form_configurable :user_id
    form_configurable :timezone



    def default_options
      {
        'username'  => '',
        'password'  => '',
        'user_id'   => '',
        'timezone'  => 'America/Los_Angeles'
      }
    end



    def validate_options
      errors.add(:base, ":username needs to be specified") if interpolated['username'].blank?
      errors.add(:base, ":password needs to be specified") if interpolated['password'].blank?

      options['password'] = 'MD5:' + Digest::MD5.hexdigest(interpolated['password']) unless md5_password
    end



    after_initialize :initialize_memory
    def initialize_memory
      memory['seen'] ||= {}
    end



    def working?
      memory['last_error'].blank?
    end



    def receive(incoming_events)
      @session_id = get_session_token
        return log_error('Failed to get session token') unless @session_id

      incoming_events.each do |event|
        data = event.attributes['payload']
        data['subcategory']  ||= to_type(data['activity_name'])
        data['timezone']     ||= options['timezone']
        data['end_time']     ||= data['start_time'].to_i + data['duration'].to_i
        data['date']         ||= Time.at(data['start_time'].to_i).in_time_zone(data['timezone']).to_date.to_s

        event_id    = data['original_id'] || event.id
        old_id      = memory.dig('seen', event_id)
        activity_id = push_activity(data, old_id)
          log('Failed to create activity', event) and next unless activity_id

        memory['seen'][event_id] = activity_id
      end

      return true
    end



    private



    def md5_password
      options['password'].starts_with?('MD5:') ? options['password'].slice(4..-1) : nil
    end



    def to_epoch(string)
      string.nil? || string.is_a?(Integer) ? string : DateTime.parse(string).to_i
    end



    def successful?(response)
      response.success? && response.parsed_response['status'] == 0
    end



    def log_error(summary, body='')
      log("#{summary} - #{body}")
      memory['last_error'] = summary
      return nil
    end



    def get_session_token
      response = HTTParty.post('https://scalews.withings.net/cgi-bin/auth',
        :body => {
          :duration   => 900,
          :email      => options['username'],
          :hash       => md5_password,
          :callctx    => :foreground,
          :action     => :login,
          :appname    => 'wiscaleNG',
          :apppfm     => 'ios',
          :appliver   => 4070033
        }
      )

      return log_error('Withings Authentication Error' , response.body) unless successful?(response)

      return response.parsed_response['body']['sessionid']
    end



    # def get_associations
    #   response = HTTParty.post('https://scalews.withings.net/cgi-bin/association',
    #     :body => {
    #       :enrich     => 't',
    #       :type       => -1,
    #       :action     => :getbyaccountid,
    #       :callctx    => 'foreground,devices',
    #       :appname    => 'wiscaleNG',
    #       :apppfm     => 'ios',
    #       :appliver   => 4070033,
    #       :sessionid  => @session_id
    #     }
    #   )
    #
    #   return error('Withings Failure while Fetching Associations', response.body) unless successful?(response)
    #
    #   user_ids = response.parsed_response['body']['associations'].map do |x|
    #     {
    #       'device_name' => x['devicename'],
    #       'timezone'    => x.dig('deviceproperties', 'timezone'),
    #       'user_id'     => x.dig('deviceproperties', 'linkuserid')
    #     }
    #   end.select{|x| x['device_name'].present? && x['user_id'].present? }
    #
    #   return user_ids.last
    # end



    def push_activity(event, activity_id=nil)
      response = HTTParty.post('https://scalews.withings.net/cgi-bin/v2/activity',
        :headers => {
          'Accept-Language' => 'en-US,en;q=0.9',
          'Content-type'    => 'text/plain;charset=UTF-8'
        },
        :body => {
          :date         => event['date'],
          :startdate    => event['start_time'],
          :enddate      => event['end_time'],
          :userid       => options['user_id'],
          :action       => activity_id ? :update : :store,
          :activityid   => activity_id,

          :subcategory  => event['subcategory'],
          :timezone     => event['timezone'],
          :attrib       => 2,
          :appname      => 'hmw',
          :apppfm       => 'web',
          :appliver     => '341d89db298beb57a91195ff812a7aa5134a510e',
          :sessionid    => @session_id,

          :data       => {
            :intensity        => event['intensity'] || 50,
            :distance         => event['distance'].to_f || 0,
            :calories         => event['calories'].to_f || 0,
          }.to_json
        }.compact
      )

      return log_error('Withings Server Refused Activity', response.body) unless successful?(response)

      return response.parsed_response['body']['id']
    end



    def to_type(name)
      case name.try(:downcase)
        when 'walking'      then 1
        when 'running'      then 2
        when 'hiking'       then 3
        when 'bicycling'    then 4
        when 'swimming'     then 5
        when 'tennis'       then 12
        when 'weights'      then 16
        when 'class'        then 17
        when 'elliptical'   then 18
        when 'basketball'   then 20
        when 'soccer'       then 21
        when 'volleyball'   then 24
        when 'yoga'         then 28
        else 36
      end
    end


  end
end
