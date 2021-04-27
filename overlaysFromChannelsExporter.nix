{ flake-utils-plus }:
let

  overlaysFromChannelsExporter = { pkgs, inputs ? { } }:
    /**
      Synopsis: overlaysFromChannelsExporter _{ pkgs, inputs }_

      pkgs: self.pkgs

      inputs: flake inputs to sort out external overlays

      Returns an attribute set of all packages defined in an overlay by any channel
      intended to be passed to be exported via _self.overlays_. This method of
      sharing has the advantage over _self.packages_, that the user will instantiate
      overlays with his proper nixpkgs version, and thereby significantly reduce their system's
      closure as they avoid depending on entirely different nixpkgs versions dependency
      trees. On the flip side, any caching that is set up for one's packages will essentially
      be useless to users.

      It can happen that an overlay is not compatible with the version of nixpkgs a user tries
      to instantiate it. In order to provide users with a visual clue for which nixpkgs version
      an overlay was originally created, we prefix the channle name: "<channelname>/<packagekey>".
      In the case of the unstable channel, this information is still of varying usefulness,
      as effective cut dates can vary heavily between repositories.

      To ensure only overlays that originate from the flake are exported you can optionally pass
      a set of flake inputs and any overlay which is taken from an input will be filtered out.
      Optimally this would be done by detecting flake ownership of each overlay, but that is not 
      possible yet, so this is the next best workaround.

      Example:

      overlays = [
      "unstable/development" = final: prev: { };
      "nixos2009/chromium" = final: prev: { };
      "nixos2009/pythonPackages" = final: prev: { };
      ];

      **/
    let
      inherit (builtins) mapAttrs foldl' filter head attrNames attrValues concatMap listToAttrs elem;
      nameValuePair = name: value: { inherit name value; };

      # just pull out one arch from the system-spaced pkgs to get access to channels
      # overlays can be safely evaluated on any arch
      channels = head (attrValues pkgs);

      pathStr = path: builtins.concatStringsSep "/" path;

      channelNames = attrNames channels;
      overlayNames = overlay: attrNames (overlay null null);

      # get all overlays from inputs
      inputOverlays = mapAttrs
        (_: v: [ v.overlay or (_: _: { }) ] ++ attrValues v.overlays or { })
        (removeAttrs inputs [ "self" ]);
      # use overlayNames as a way to identify overlays
      flattenedInputOverlays = map overlayNames (foldl' (a: b: a ++ b) [ ] (attrValues inputOverlays));

      extractAndNamespaceEachOverlay = channelName: overlay:
        map
          (overlayName:
            nameValuePair
              (pathStr [ channelName overlayName ])
              (final: prev: {
                ${overlayName} = (overlay final prev).${overlayName};
              })
          )
          (overlayNames overlay);

      filterOverlays = channel:
        filter
          (overlay: !elem (overlayNames overlay) flattenedInputOverlays)
          channel.overlays;

    in
    listToAttrs (
      concatMap
        (channelName:
          concatMap
            (overlay:
              extractAndNamespaceEachOverlay channelName overlay
            )
            (filterOverlays channels.${channelName})
        )
        channelNames
    );

in
overlaysFromChannelsExporter