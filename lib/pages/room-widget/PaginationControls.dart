import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

enum PaginationPosition { left, right, bottom }

class PaginationControls extends StatefulWidget {
  final PageController pageController;
  final int pageCount;
  final PaginationPosition position;

  const PaginationControls({
    super.key,
    required this.pageController,
    required this.pageCount,
    required this.position,
  });

  @override
  _PaginationControlsState createState() => _PaginationControlsState();
}

class _PaginationControlsState extends State<PaginationControls> {
  late final ValueNotifier<int> _currentPageNotifier;

  @override
  void initState() {
    super.initState();
    _currentPageNotifier = ValueNotifier<int>(0);
    widget.pageController.addListener(_updateCurrentPage);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_updateCurrentPage);
    _currentPageNotifier.dispose();
    super.dispose();
  }

  void _updateCurrentPage() {
    _currentPageNotifier.value = widget.pageController.page?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: widget.position == PaginationPosition.left
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        if (widget.position == PaginationPosition.left)
          ValueListenableBuilder<int>(
            valueListenable: _currentPageNotifier,
            builder: (context, currentPage, child) {
              return Opacity(
                opacity: currentPage > 0 ? 1.0 : 0.3,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white, // Background color
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4.0,
                          spreadRadius: 1.0,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.black, // Arrow color
                    ),
                  ),
                  onPressed: () {
                    if (currentPage > 0) {
                      widget.pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              );
            },
          ),
        if (widget.position == PaginationPosition.right)
          ValueListenableBuilder<int>(
            valueListenable: _currentPageNotifier,
            builder: (context, currentPage, child) {
              return Opacity(
                opacity: currentPage < (widget.pageCount - 1) ? 1.0 : 0.3,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white, // Background color
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4.0,
                          spreadRadius: 1.0,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.black, // Arrow color
                    ),
                  ),
                  onPressed: () {
                    if (currentPage < widget.pageCount - 1) {
                      widget.pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              );
            },
          ),
        
       
      
          
      ],
    );
  }
}
