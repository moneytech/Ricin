using Tox;

[GtkTemplate (ui="/chat/tox/Ricin/main-window.ui")]
public class Ricin.MainWindow : Gtk.ApplicationWindow {
  [GtkChild] Gtk.Entry entry_name;
  [GtkChild] Gtk.Entry entry_status;
  [GtkChild] Gtk.Button button_user_status;
  [GtkChild] Gtk.Image image_user_status;
  [GtkChild] Gtk.ListBox friendlist;
  [GtkChild] Gtk.Label toxid;
  [GtkChild] Gtk.Stack chat_stack;
  [GtkChild] Gtk.Button button_add_friend_show;

  // Add friend revealer
  [GtkChild] Gtk.Revealer add_friend;
  [GtkChild] Gtk.Entry entry_friend_id;
  [GtkChild] Gtk.TextView entry_friend_message;
  [GtkChild] Gtk.Label label_add_error;
  [GtkChild] Gtk.Button button_add_friend;
  [GtkChild] Gtk.Button button_cancel_add;

  private ListStore friends = new ListStore (typeof (Tox.Friend));

  Tox.Tox tox;

  public MainWindow (Ricin app) {
    Object (application: app);

    var options = Tox.Options.create ();
    options.ipv6_enabled = true;
    options.udp_enabled = true;
    this.tox = new Tox.Tox (options);

    this.toxid.label += this.tox.id;

    /* TEMP ZONE */
    this.button_add_friend_show.clicked.connect (() => {
      this.entry_friend_message.buffer.text = "Hello, I'm " + this.tox.username + ". Currently using Ricin, please add this friend request then we could talk!";
      this.button_add_friend_show.visible = false;
      this.label_add_error.visible = false;
      this.add_friend.reveal_child = true;
    });

    this.button_add_friend.clicked.connect (() => {
      var tox_id = this.entry_friend_id.get_text ();
      var message = this.entry_friend_message.buffer.text;
      var error_message = "";

      if (tox_id.length == 76) {
        var friend = tox.add_friend (tox_id, message);
        this.entry_friend_id.set_text (""); // Clear the entry after adding a friend.
        return;
        //this.friends.append (friend);
      } else if (tox_id.index_of ("@") != -1) {
        error_message = "Ricin doesn't supports ToxDNS yet.";
      } else {
        error_message = "Invalid ToxID.";
      }

      if (error_message.strip () != "") {
        this.label_add_error.visible = true;
        this.label_add_error.set_text (error_message);
        return;
      }

      this.add_friend.reveal_child = false;
      this.button_add_friend_show.visible = true;
    });

    this.button_cancel_add.clicked.connect (() => {
      this.add_friend.reveal_child = false;
      this.button_add_friend_show.visible = true;
    });
    /* TEMP ZONE */

    this.friendlist.bind_model (this.friends, fr => new FriendListRow (fr as Tox.Friend));
    this.friendlist.row_activated.connect ((lb, row) => {
      var fr = (row as FriendListRow).fr;
      foreach (var view in chat_stack.get_children ()) {
        if ((view as ChatView).fr == fr) {
          chat_stack.set_visible_child (view);
          (view as ChatView).entry.grab_focus ();
          break;
        }
      }
    });

    this.entry_name.activate.connect (() => this.tox.username = Util.escape_html (this.entry_name.text));
    this.entry_status.bind_property ("text", this.tox, "status_message", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

    this.button_user_status.clicked.connect (() => {
      var status = this.tox.status;
      switch (status) {
        case UserStatus.ONLINE:
          // Set status to away.
          this.tox.status = UserStatus.AWAY;
          this.image_user_status.icon_name = "user-away";
          break;
        case UserStatus.AWAY:
          // Set status to busy.
          this.tox.status = UserStatus.BUSY;
          this.image_user_status.icon_name = "user-busy";
          break;
        case UserStatus.BUSY:
          // Set status to online.
          this.tox.status = UserStatus.ONLINE;
          this.image_user_status.icon_name = "user-available";
          break;
        default:
          this.image_user_status.icon_name = "user-offline";
          break;
      }
    });

    this.tox.notify["connected"].connect ((src, prop) => {
      this.image_user_status.icon_name = this.tox.connected ? "user-available" : "user-offline";
      this.button_user_status.sensitive = this.tox.connected;
    });

    this.tox.friend_request.connect ((id, message) => {
      var dialog = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "Friend request from:");
      dialog.secondary_text = @"$id\n\n$message";
      dialog.add_buttons ("Accept", Gtk.ResponseType.ACCEPT, "Reject", Gtk.ResponseType.REJECT);
      dialog.response.connect (response => {
        if (response == Gtk.ResponseType.ACCEPT) {
          var friend = tox.accept_friend_request (id);
          if (friend != null) {
            friends.append (friend);
            chat_stack.add_named (new ChatView (this.tox, friend), friend.name);
          }
        }
        dialog.destroy ();
      });
      dialog.show ();
    });

    this.tox.friend_online.connect ((friend) => {
      if (friend != null) {
        friends.append (friend);
        chat_stack.add_named (new ChatView (this.tox, friend), friend.name);
      }
    });

    this.tox.run_loop ();

    this.show_all ();
  }
}
